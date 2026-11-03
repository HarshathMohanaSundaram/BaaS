class AddScopedUniqueIndex < ActiveRecord::Migration[8.1]
  def change
    add_index :users, [:organization_id, :email], unique: true, name: 'index_users_on_organization_and_email' 
  end
end
