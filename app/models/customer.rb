class Customer < ApplicationRecord
  belongs_to :organization
  # Keyed on account_manager_id alone: a composite key would make assigning a manager overwrite organization_id.
  # The composite FK in the database (fk_customers_account_manager) still enforces the same-organization rule.
  belongs_to :account_manager, class_name: "User", foreign_key: :account_manager_id, optional: true

  validates :name, :email, :payment_type, presence: true
  validates :external_id, presence: true, uniqueness: { scope: :organization_id }
  validate :account_manager_belongs_to_same_organization

  enum :payment_type, { credit_card: 0, bank_transfer: 1, cash: 2, check: 3 }

  private

  def account_manager_belongs_to_same_organization
    return if account_manager.nil?
    # organization&.id, not organization_id: the column is only synced from an assigned organization on save
    return if account_manager.organization_id == organization&.id

    errors.add(:account_manager, "must belong to the same organization")
  end
end
