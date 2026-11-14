class AddStripeInOrganization < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :stripe_account_id, :string
  end
end
