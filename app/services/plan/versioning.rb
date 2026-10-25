class Plan::Versioning
  # attributes a caller may change; anything else in params is rejected
  EDITABLE_ATTRIBUTES = %w[name amount interval per_quantity metric].freeze
  # attributes that can be updated in place without creating a new version
  NON_VERSIONED_ATTRIBUTES = %w[name].freeze

  attr_accessor :plan, :params

  def initialize(plan, params)
    @plan = plan
    @params = params.to_h.stringify_keys
  end

  # this method will be executing the plan versioning logic
  # if any attribute other than name has changed, it will create a new plan with the updated attributes, increase the version number, and archive the old plan
  # if only the name has changed, the plan is updated in place
  # the plan row is locked (SELECT ... FOR UPDATE) for the whole operation so concurrent requests are serialized
  #
  # returns the current version of the plan: the new plan when a version was created, otherwise the same plan
  # raises InvalidRecordError for bad params and ConflictError when the plan can no longer be updated
  def execute
    reject_non_editable_attributes!

    plan.with_lock do
      # with_lock reloads the plan, so this sees any change committed by a request that held the lock before us
      raise ConflictError, "Plan has been archived and can no longer be updated" if plan.archived?

      # assign first so dirty tracking compares type-cast values (e.g. "100" vs 100, "monthly" vs 1)
      plan.assign_attributes(params)
      # validated before anything is written, so a bad amount fails the same way as a bad name
      raise InvalidRecordError.new(plan) unless plan.valid?

      if versioned_attributes_changed?
        create_new_version
      else
        plan.save!
        plan
      end
    end
  rescue ActiveRecord::RecordNotUnique
    # the unique index on previous_plan_id is the backstop if another version of this plan got written anyway;
    # rescued here, outside with_lock, so the transaction has already rolled back
    raise ConflictError, "Plan has already been versioned"
  end

  private

  def reject_non_editable_attributes!
    non_editable = params.keys - EDITABLE_ATTRIBUTES
    return if non_editable.empty?

    non_editable.each { |attribute| plan.errors.add(:base, "#{attribute} cannot be changed") }
    raise InvalidRecordError.new(plan)
  end

  def versioned_attributes_changed?
    (plan.changed - NON_VERSIONED_ATTRIBUTES).any?
  end

  # runs inside the transaction opened by with_lock, so archiving and the insert commit or roll back together
  def create_new_version
    # dup carries over the assigned (changed) attributes and the lineage key, then the old plan is reverted before archiving
    new_plan = plan.dup
    new_plan.version = plan.version + 1
    new_plan.previous_plan_id = plan.id
    new_plan.archived = false

    plan.restore_attributes
    plan.update!(archived: true)
    new_plan.save!
    new_plan
  end
end
