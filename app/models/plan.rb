class Plan < ApplicationRecord
  # Associations belongs to a organization and previous_plan mapping previous plan
  belongs_to :organization
  belongs_to :previous_plan, class_name: 'Plan', primary_key: :id, foreign_key: :previous_plan_id, optional: true

  # enums for interval
  enum :interval, { monthly: 1, yearly: 2 }

  # Validations for presence and uniqueness
  validates :name, presence: true
  validates :amount, presence: true
  validates :interval, presence: true
  validates :version, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :metric, presence: true, if: :per_quantity?
end