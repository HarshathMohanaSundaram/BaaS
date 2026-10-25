class Plan::Versioning
  # attributes that can be updated in place without creating a new version
  NON_VERSIONED_ATTRIBUTES = %w[name].freeze

  attr_accessor :plan, :params

  def initialize(plan, params)
    @plan = plan
    @params = params
  end

  # this method will be executing the plan versioning logic
  # if any attribute other than name has changed, it will create a new plan with the updated attributes, increase the version number, and archive the old plan
  # if only the name has changed, the plan is updated in place
  # the plan row is locked (SELECT ... FOR UPDATE) for the whole operation so concurrent requests are serialized
  def execute
    plan.with_lock do
      # with_lock reloads the plan, so this sees any change committed by a request that held the lock before us
      if plan.archived?
        plan.errors.add(:base, "has been archived and can no longer be updated")
        next false
      end

      # assign first so dirty tracking compares type-cast values (e.g. "100" vs 100, "monthly" vs 1)
      plan.assign_attributes(params)

      if versioned_attributes_changed?
        create_new_version
      else
        plan.save
      end
    end
  end

  private

  def versioned_attributes_changed?
    (plan.changed - NON_VERSIONED_ATTRIBUTES).any?
  end

  # runs inside the transaction opened by with_lock
  def create_new_version
    # dup carries over the assigned (changed) attributes, then the old plan is reverted before archiving
    new_plan = plan.dup
    new_plan.version = plan.version + 1
    new_plan.previous_plan_id = plan.id
    new_plan.archived = false

    plan.restore_attributes
    Plan.transaction do
      plan.update!(archived: true)
      new_plan.save!
    end
    new_plan
  end
end
