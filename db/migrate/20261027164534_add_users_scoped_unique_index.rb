class AddUsersScopedUniqueIndex < ActiveRecord::Migration[8.1]
  def change
    remove_index :users, column: :organization_id
    add_index :users, [:organization_id, :id], unique: true, name: 'index_users_on_organization_and_id' 
  end
end
