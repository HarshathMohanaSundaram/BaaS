class AddConstraintsOrganizationPlans < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :plans, "amount >= 0", name: "amount_non_negative"
    add_check_constraint :plans, "interval in (1,2)", name: "interval_valid"
    add_check_constraint :plans, "per_quantity = true AND metric IS NOT NULL", name: "per_quantity_metric_not_null"
    add_check_constraint :plans, "per_quantity = false AND metric IS NULL", name: "per_quantity_metric_null"
    add_check_constraint :organizations, "currency_type in (1,2,3)", name: "currency_type_valid"
  end
end
