class AddLineageKeyForPlansAndIndexes < ActiveRecord::Migration[8.1]
  # plans has no records yet, so no backfill: a table with existing version chains would need each
  # chain to inherit its root's key, because the default gives every row its own
  def change
    add_column :plans, :lineage_key, :uuid, null: false, default: -> { "gen_random_uuid()" }

    # targets for the composite foreign keys below
    add_index :plans, [ :id, :lineage_key ], unique: true, name: "index_plans_on_id_and_lineage_key"
    add_index :plans, [ :id, :organization_id ], unique: true, name: "index_plans_on_id_and_organization_id"

    # a version must share its predecessor's lineage key and organization
    add_foreign_key :plans, :plans, column: [ :previous_plan_id, :lineage_key ], primary_key: [ :id, :lineage_key ],
                    name: "fk_plans_previous_plan_same_lineage"
    add_foreign_key :plans, :plans, column: [ :previous_plan_id, :organization_id ], primary_key: [ :id, :organization_id ],
                    name: "fk_plans_previous_plan_same_organization"
  end
end
