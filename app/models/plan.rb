class Plan < ApplicationRecord
  # Associations belongs to a organization and previous_plan mapping previous plan
  belongs_to :organization
  belongs_to :previous_plan, class_name: "Plan", primary_key: :id, foreign_key: :previous_plan_id, optional: true

  # enums for interval
  enum :interval, { monthly: 1, yearly: 2 }

  # Validations for presence and uniqueness
  validates :name, presence: true
  validates :interval, presence: true
  validates :version, presence: true
  validates :amount, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :metric, presence: true, if: :per_quantity?
  validates :metric, absence: true, unless: :per_quantity?
  validate :previous_plan_belongs_to_same_organization

  scope :active, -> { where(archived: false) }

  private

  def previous_plan_belongs_to_same_organization
    return if previous_plan.nil?
    return if previous_plan.organization_id == organization_id

    errors.add(:previous_plan, "must belong to the same organization")
  end
end
