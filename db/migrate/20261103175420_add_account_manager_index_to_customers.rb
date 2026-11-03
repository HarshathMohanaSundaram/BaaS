class AddAccountManagerIndexToCustomers < ActiveRecord::Migration[8.1]
  def change
    # Covers fk_customers_account_manager, so deleting or moving a user doesn't scan the whole customers table.
    add_index :customers, [ :account_manager_id, :organization_id ], name: 'index_customers_on_account_manager'
  end
end
