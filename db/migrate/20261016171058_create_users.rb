class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false, index: { unique: true, name: 'index_users_on_email_unique' }
      t.string :password_digest, null: false
      t.references :organization, null: false, foreign_key: true
      t.integer :role, null: false, default: 0
      t.timestamps
    end
  end
end
