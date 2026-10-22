class CreatePlans < ActiveRecord::Migration[8.1]
  def change
    create_table :plans do |t|
      t.references :organization, null: false, foreign_key: true, index: false
      t.string :name, null: false
      t.integer :amount, null: false
      t.boolean :per_quantity, null: false, default: false
      t.string :metric
      t.integer :interval, null: false
      t.integer :version, null: false, default: 1
      t.references :previous_plan, foreign_key: { to_table: :plans }, index: { unique: true, name: 'index_plans_on_previous_plan_id' }
      t.boolean :archived, null: false, default: false
      t.timestamps
    end

    add_index :plans, [:organization_id, :archived], name: 'index_plans_on_organization_id_and_archived'
  end
end
