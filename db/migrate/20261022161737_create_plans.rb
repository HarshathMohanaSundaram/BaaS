class CreatePlans < ActiveRecord::Migration[8.1]
  def change
    create_table :plans do |t|
      t.references :organization, null: false, foreign_key: true, index: { name: 'index_plans_on_organization_id' }
      t.string :name, null: false
      t.float :amount, null: false
      t.boolean :per_quantity, null: false, default: false
      t.string :metric
      t.integer :interval, null: false
      t.integer :version, null: false, default: 1
      t.bigint :previous_plan_id
      t.boolean :archived, null: false, default: false, index: { name: 'index_plans_on_archived' }
      t.timestamps
    end
  end
end
