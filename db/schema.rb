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

ActiveRecord::Schema[8.0].define(version: 2025_10_25_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "daily_prods", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "month"
    t.date "date"
    t.integer "manual_total"
    t.integer "auto_total"
    t.integer "overall_total"
    t.integer "duplicates_total"
    t.integer "created_property_total"
    t.decimal "daily_average", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status"
    t.index ["date"], name: "index_daily_prods_on_date"
    t.index ["month"], name: "index_daily_prods_on_month"
    t.index ["status"], name: "index_daily_prods_on_status"
    t.index ["user_id"], name: "index_daily_prods_on_user_id"
  end

  create_table "prod_entries", force: :cascade do |t|
    t.bigint "entered_by_user_id", null: false
    t.bigint "supplier_id", null: false
    t.bigint "assigned_user_id"
    t.date "date"
    t.integer "mapping_type", null: false
    t.integer "manually_mapped"
    t.integer "incorrect_supplier_data"
    t.integer "created_property"
    t.integer "insufficient_info"
    t.integer "accepted"
    t.integer "dismissed"
    t.integer "no_result"
    t.integer "duplicate"
    t.integer "reactivated"
    t.integer "source", null: false
    t.text "remarks"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_user_id"], name: "index_prod_entries_on_assigned_user_id"
    t.index ["date"], name: "index_prod_entries_on_date"
    t.index ["entered_by_user_id"], name: "index_prod_entries_on_entered_by_user_id"
    t.index ["supplier_id"], name: "index_prod_entries_on_supplier_id"
  end

  create_table "summary_dashboards", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.date "period_start", null: false
    t.date "period_end"
    t.integer "manual_total"
    t.integer "auto_total"
    t.integer "incorrect_data_total"
    t.integer "dismissed_total"
    t.integer "duplicate_total"
    t.integer "total_productivity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_summary_dashboards_on_user_id"
  end

  create_table "suppliers", force: :cascade do |t|
    t.string "name", null: false
    t.date "request_date"
    t.date "start_date"
    t.date "completed_date"
    t.integer "priority", default: 1, null: false
    t.string "requester"
    t.integer "status", default: 1
    t.integer "total_requests"
    t.integer "total_mapped"
    t.integer "total_pending"
    t.integer "automapping_covered_total"
    t.integer "suggestions_total"
    t.integer "accepted_total"
    t.integer "dismissed_total"
    t.integer "manual_total"
    t.integer "manually_mapped"
    t.integer "incorrect_supplier_data"
    t.integer "duplicate_count"
    t.integer "created_property"
    t.integer "not_covered"
    t.integer "nc_manually_mapped"
    t.integer "nc_created_property"
    t.integer "nc_incorrect_supplier"
    t.integer "jp_props"
    t.integer "reactivated_total"
    t.text "remarks"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "assigned_pic_id", null: false
    t.index ["assigned_pic_id"], name: "index_suppliers_on_assigned_pic_id"
    t.index ["completed_date"], name: "index_suppliers_on_completed_date"
    t.index ["start_date"], name: "index_suppliers_on_start_date"
    t.index ["status"], name: "index_suppliers_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "google_id"
    t.integer "role", default: 3, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["google_id"], name: "index_users_on_google_id"
  end

  add_foreign_key "daily_prods", "users"
  add_foreign_key "prod_entries", "suppliers"
  add_foreign_key "prod_entries", "users", column: "assigned_user_id"
  add_foreign_key "prod_entries", "users", column: "entered_by_user_id"
  add_foreign_key "summary_dashboards", "users"
  add_foreign_key "suppliers", "users", column: "assigned_pic_id"
end
