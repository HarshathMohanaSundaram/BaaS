class CreateApiKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :api_keys do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :prefix, null: false
      t.string :digest, null: false
      t.string :name, null: false
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps
    end

    add_index :api_keys, :prefix, unique: true, name: 'index_api_keys_on_organization_and_prefix'
    add_index :api_keys, :digest, unique: true, name: 'index_api_keys_on_digest'
  end
end
