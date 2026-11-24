class AddAccountVerifiedInOrganization < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :account_verified, :boolean, default: false
  end
end
