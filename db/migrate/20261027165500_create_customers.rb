class CreateCustomers < ActiveRecord::Migration[8.1]
  def change
    create_table :customers do |t|
      t.references :organization, null: false, foreign_key: true, index: false
      t.bigint :account_manager_id
      t.string :name, null: false
      t.string :email, null: false
      t.string :external_id, null: false
      t.string :stripe_customer_id
      t.integer :payment_type, null: false, default: 0
      t.timestamps
    end

    add_index :customers, [ :organization_id, :external_id ], unique: true, name: 'index_customers_on_organization_and_external_id'
  add_index :customers, :stripe_customer_id, unique: true, name: 'index_customers_on_stripe_customer_id'
    add_foreign_key :customers, :users, column: [ :account_manager_id, :organization_id ], primary_key: [ :id, :organization_id ], name: 'fk_customers_account_manager'
    add_index :customers, [ :id, :organization_id ], unique: true, name: 'index_customers_on_id_and_organization_id'
  end
end
