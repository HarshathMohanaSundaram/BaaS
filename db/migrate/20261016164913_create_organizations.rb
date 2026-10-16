class CreateOrganizations < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations do |t|
      t.string :name, null: false
      t.string :email, null: false, index: { unique: true, name: 'index_organizations_on_email_unique' }
      t.integer :business_type, null: false
      t.integer :currency_type, null: false
      t.integer :last_invoice_number, null: false, default: 0
      t.timestamps
    end
  end
end
