class Subscription < ApplicationRecord
  # This is the status to be used for partial uniqueness index with customers
  LIVE_STATUSES = %i[trialing active past_due].freeze

  enum :status, { trialing: 1, active: 2, past_due: 3, canceled: 4 }, validate: true

  belongs_to :organization
  belongs_to :plan
  belongs_to :customer

  validates :status, :current_period_start, :lineage_key, presence: true
  validates :cancel_at_period_end, inclusion: { in: [ true, false ] }
  validates :canceled_at, absence: true, unless: :canceled?
  validates :canceled_at, presence: true, if: :canceled?
  validates :current_period_end, presence: true, comparison: { greater_than: :current_period_start }
  validate :lineage_key_belongs_to_plan
  validate :subscribing_live_plan, on: :create
  validate :customer_organization_consistency
  validate :plan_organization_consistency
  validates :lineage_key, uniqueness: { scope: :customer_id, conditions: -> { where(status: LIVE_STATUSES.map { |s| statuses[s] }) }, message: "is already taken for a live subscription for this customer" }, if: :live?

  def live?
    LIVE_STATUSES.any? { |status| send("#{status}?") }
  end

  private

  def lineage_key_belongs_to_plan
    return if plan.nil? || plan.lineage_key == lineage_key

    errors.add(:lineage_key, "must match the plan's lineage key")
  end

  def customer_organization_consistency
    return if customer.nil? || customer.organization_id == organization_id
    errors.add(:customer, "must belong to the same organization as the subscription")
  end

  def plan_organization_consistency
    return if plan.nil? || plan.organization_id == organization_id
    errors.add(:plan, "must belong to the same organization as the subscription")
  end

  def subscribing_live_plan
    return if plan.nil? || plan.live?

    errors.add(:plan, "must be live to create a subscription")
  end
end
