class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.references :organization, null: false, foreign_key: true, index: { name: "index_subscriptions_on_organization_id" }
      t.bigint :customer_id, null: false
      t.bigint :plan_id, null: false
      t.integer :status, null: false
      t.datetime :current_period_start, null: false
      t.datetime :current_period_end, null: false
      t.datetime :trial_ends_at
      t.boolean :cancel_at_period_end, null: false, default: false
      t.datetime :canceled_at
      t.uuid :lineage_key, null: false
      t.timestamps
    end

    add_foreign_key :subscriptions, :customers, column: [ :customer_id, :organization_id ], primary_key: [ :id, :organization_id ], name: 'fk_subscriptions_customer'
    add_foreign_key :subscriptions, :plans, column: [ :plan_id, :organization_id ], primary_key: [ :id, :organization_id ], name: 'fk_subscriptions_plan_organization'
    add_foreign_key :subscriptions, :plans, column: [ :plan_id, :lineage_key ], primary_key: [ :id, :lineage_key ], name: 'fk_subscriptions_plan_lineage'
    add_index :subscriptions, [ :customer_id, :organization_id ], name: 'index_subscriptions_on_customer_id_and_organization_id'
    add_index :subscriptions, [ :plan_id, :organization_id ], name: 'index_subscriptions_on_plan_id_and_organization_id'
    add_index :subscriptions, [ :customer_id, :lineage_key ], unique: true, where: "status in (1, 2, 3)", name: 'index_live_unique_subscriptions_on_customer_id_and_lineage_key'

    add_check_constraint :subscriptions, "current_period_end > current_period_start", name: "check_current_period_end_after_start"
    add_check_constraint :subscriptions, "status in (1, 2, 3, 4)", name: "check_status_enum"
    add_check_constraint(:subscriptions,
    <<~SQL,
      CASE WHEN status = 4 AND canceled_at IS NOT NULL THEN TRUE
           WHEN status <> 4 AND canceled_at IS NULL THEN TRUE
            ELSE FALSE
      END = TRUE
    SQL
    name: "check_canceled_at_status_consistency")
  end
end
