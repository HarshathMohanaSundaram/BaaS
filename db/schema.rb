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

ActiveRecord::Schema[8.1].define(version: 2026_11_06_135220) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "api_keys", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "user_id", null: false
    t.string "prefix", null: false
    t.string "digest", null: false
    t.string "name", null: false
    t.datetime "last_used_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["digest"], name: "index_api_keys_on_digest", unique: true
    t.index ["organization_id"], name: "index_api_keys_on_organization_id"
    t.index ["prefix"], name: "index_api_keys_on_prefix"
    t.index ["user_id"], name: "index_api_keys_on_user_id"
    t.check_constraint "digest::text <> ''::text", name: "check_api_keys_digest_not_empty"
    t.check_constraint "name::text <> ''::text", name: "check_api_keys_name_not_empty"
    t.check_constraint "prefix::text <> ''::text", name: "check_api_keys_prefix_not_empty"
  end

  create_table "customers", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "account_manager_id"
    t.string "name", null: false
    t.string "email", null: false
    t.string "external_id", null: false
    t.string "stripe_customer_id"
    t.integer "payment_type", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_manager_id", "organization_id"], name: "index_customers_on_account_manager"
    t.index ["id", "organization_id"], name: "index_customers_on_id_and_organization_id", unique: true
    t.index ["organization_id", "external_id"], name: "index_customers_on_organization_and_external_id", unique: true
    t.index ["stripe_customer_id"], name: "index_customers_on_stripe_customer_id", unique: true
    t.check_constraint "external_id::text <> ''::text", name: "check_customers_external_id_not_empty"
    t.check_constraint "payment_type = ANY (ARRAY[0, 1, 2, 3])", name: "check_customers_payment_type_valid"
  end

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
    t.uuid "lineage_key", default: -> { "gen_random_uuid()" }, null: false
    t.index ["id", "lineage_key"], name: "index_plans_on_id_and_lineage_key", unique: true
    t.index ["id", "organization_id"], name: "index_plans_on_id_and_organization_id", unique: true
    t.index ["organization_id", "archived"], name: "index_plans_on_organization_id_and_archived"
    t.index ["previous_plan_id"], name: "index_plans_on_previous_plan_id", unique: true
    t.check_constraint "\"interval\" = ANY (ARRAY[1, 2])", name: "interval_valid"
    t.check_constraint "amount >= 0", name: "amount_non_negative"
    t.check_constraint "per_quantity = true AND metric IS NOT NULL OR per_quantity = false AND metric IS NULL", name: "per_quantity_metric_consistency"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "customer_id", null: false
    t.bigint "plan_id", null: false
    t.integer "status", null: false
    t.datetime "current_period_start", null: false
    t.datetime "current_period_end", null: false
    t.datetime "trial_ends_at"
    t.boolean "cancel_at_period_end", default: false, null: false
    t.datetime "canceled_at"
    t.uuid "lineage_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id", "lineage_key"], name: "index_live_unique_subscriptions_on_customer_id_and_lineage_key", unique: true, where: "(status = ANY (ARRAY[1, 2, 3]))"
    t.index ["customer_id", "organization_id"], name: "index_subscriptions_on_customer_id_and_organization_id"
    t.index ["organization_id"], name: "index_subscriptions_on_organization_id"
    t.index ["plan_id", "organization_id"], name: "index_subscriptions_on_plan_id_and_organization_id"
    t.check_constraint "\nCASE\n    WHEN status = 4 AND canceled_at IS NOT NULL THEN true\n    WHEN status <> 4 AND canceled_at IS NULL THEN true\n    ELSE false\nEND = true", name: "check_canceled_at_status_consistency"
    t.check_constraint "current_period_end > current_period_start", name: "check_current_period_end_after_start"
    t.check_constraint "status = ANY (ARRAY[1, 2, 3, 4])", name: "check_status_enum"
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
    t.index ["organization_id", "id"], name: "index_users_on_organization_and_id", unique: true
  end

  add_foreign_key "api_keys", "organizations"
  add_foreign_key "api_keys", "users"
  add_foreign_key "customers", "organizations"
  add_foreign_key "customers", "users", column: ["account_manager_id", "organization_id"], primary_key: ["id", "organization_id"], name: "fk_customers_account_manager"
  add_foreign_key "plans", "organizations"
  add_foreign_key "plans", "plans", column: "previous_plan_id"
  add_foreign_key "plans", "plans", column: ["previous_plan_id", "lineage_key"], primary_key: ["id", "lineage_key"], name: "fk_plans_previous_plan_same_lineage"
  add_foreign_key "plans", "plans", column: ["previous_plan_id", "organization_id"], primary_key: ["id", "organization_id"], name: "fk_plans_previous_plan_same_organization"
  add_foreign_key "subscriptions", "customers", column: ["customer_id", "organization_id"], primary_key: ["id", "organization_id"], name: "fk_subscriptions_customer"
  add_foreign_key "subscriptions", "organizations"
  add_foreign_key "subscriptions", "plans", column: ["plan_id", "lineage_key"], primary_key: ["id", "lineage_key"], name: "fk_subscriptions_plan_lineage"
  add_foreign_key "subscriptions", "plans", column: ["plan_id", "organization_id"], primary_key: ["id", "organization_id"], name: "fk_subscriptions_plan_organization"
  add_foreign_key "users", "organizations"
end
