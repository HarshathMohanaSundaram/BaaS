class AddCheckConstraintsForCustomerAndApiKeys < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :customers, "external_id <> ''", name: 'check_customers_external_id_not_empty'
    add_check_constraint :api_keys, "name <> ''", name: 'check_api_keys_name_not_empty'
  end
end
