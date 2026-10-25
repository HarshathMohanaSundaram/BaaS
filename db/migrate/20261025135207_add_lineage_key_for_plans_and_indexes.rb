class AddLineageKeyForPlansAndIndexes < ActiveRecord::Migration[8.1]
  def change
    add_column :plans, :lineage_key, :uuid, null: false, default: -> { "gen_random_uuid()" }
    add_index :plans, [:id, :lineage_key], unique: true, name: 'index_plans_on_organization_id_and_lineage_key'
    add_index :plans, [:id, :organization_id], unique: true, name: 'index_plans_on_id_and_organization_id'
  end
end
