# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_22_162212) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.integer "business_type", null: false
    t.integer "currency_type", null: false
    t.integer "last_invoice_number", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_organizations_on_email_unique", unique: true
    t.check_constraint "currency_type = ANY (ARRAY[1, 2, 3])", name: "currency_type_valid"
  end

  create_table "plans", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "name", null: false
    t.integer "amount", null: false
    t.boolean "per_quantity", default: false, null: false
    t.string "metric"
    t.integer "interval", null: false
    t.integer "version", default: 1, null: false
    t.bigint "previous_plan_id"
    t.boolean "archived", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "archived"], name: "index_plans_on_organization_id_and_archived"
    t.index ["organization_id"], name: "index_plans_on_organization_id"
    t.index ["previous_plan_id"], name: "index_plans_on_previous_plan_id", unique: true
    t.check_constraint "\"interval\" = ANY (ARRAY[1, 2])", name: "interval_valid"
    t.check_constraint "amount >= 0", name: "amount_non_negative"
    t.check_constraint "per_quantity = true AND metric IS NOT NULL", name: "per_quantity_metric_not_null"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.bigint "organization_id", null: false
    t.integer "role", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email_unique", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
  end

  add_foreign_key "plans", "organizations"
  add_foreign_key "plans", "plans", column: "previous_plan_id"
  add_foreign_key "users", "organizations"
end
