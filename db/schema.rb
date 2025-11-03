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

ActiveRecord::Schema[8.0].define(version: 2025_11_02_140321) do
  create_schema "auth"
  create_schema "extensions"
  create_schema "graphql"
  create_schema "graphql_public"
  create_schema "pgbouncer"
  create_schema "realtime"
  create_schema "storage"
  create_schema "vault"

  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "ai_schedule_results", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.jsonb "input_data", null: false
    t.jsonb "ai_result"
    t.text "model_name"
    t.string "status", limit: 20, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_ai_schedule_results_on_created_at", order: :desc
    t.index ["status"], name: "index_ai_schedule_results_on_status"
    t.index ["user_id"], name: "index_ai_schedule_results_on_user_id"
  end

  create_table "courses", force: :cascade do |t|
    t.text "course_code", null: false
    t.text "course_name", null: false
    t.integer "credits", null: false
    t.jsonb "schedule"
    t.text "lecturer"
    t.text "semester", null: false
    t.bigint "crawl_course_config_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_code"], name: "index_courses_on_course_code"
    t.index ["crawl_course_config_id"], name: "idx_courses_config_id"
    t.index ["crawl_course_config_id"], name: "index_courses_on_crawl_course_config_id"
    t.index ["semester"], name: "index_courses_on_semester"
  end

  create_table "crawl_course_configs", force: :cascade do |t|
    t.text "config_name", null: false
    t.text "url", null: false
    t.bigint "user_id", null: false
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active"], name: "index_crawl_course_configs_on_is_active"
    t.index ["user_id"], name: "idx_crawl_course_config_created_by"
    t.index ["user_id"], name: "index_crawl_course_configs_on_user_id"
  end

  create_table "crawl_course_jobs", force: :cascade do |t|
    t.bigint "crawl_course_config_id", null: false
    t.string "status", limit: 20, null: false
    t.jsonb "run_result"
    t.timestamptz "started_at", default: -> { "now()" }
    t.timestamptz "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["crawl_course_config_id"], name: "idx_crawl_course_job_config_id"
    t.index ["crawl_course_config_id"], name: "index_crawl_course_jobs_on_crawl_course_config_id"
    t.index ["started_at"], name: "index_crawl_course_jobs_on_started_at", order: :desc
    t.index ["status"], name: "index_crawl_course_jobs_on_status"
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "subscription_plan_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.text "payment_method", null: false
    t.text "status", null: false
    t.jsonb "transaction_data"
    t.timestamptz "expired_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_payments_on_created_at", order: :desc
    t.index ["status"], name: "index_payments_on_status"
    t.index ["subscription_plan_id"], name: "index_payments_on_subscription_plan_id"
    t.index ["user_id"], name: "index_payments_on_user_id"
  end

  create_table "subscription_plans", force: :cascade do |t|
    t.text "name", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.integer "duration_days", null: false
    t.jsonb "features"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active"], name: "index_subscription_plans_on_is_active"
    t.index ["name"], name: "index_subscription_plans_on_name"
  end

  create_table "users", force: :cascade do |t|
    t.text "email", null: false
    t.text "name"
    t.jsonb "tokens"
    t.bigint "subscription_plan_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["subscription_plan_id"], name: "index_users_on_subscription_plan_id"
  end

  add_foreign_key "ai_schedule_results", "users"
  add_foreign_key "courses", "crawl_course_configs"
  add_foreign_key "crawl_course_configs", "users"
  add_foreign_key "crawl_course_jobs", "crawl_course_configs"
  add_foreign_key "payments", "subscription_plans"
  add_foreign_key "payments", "users"
  add_foreign_key "users", "subscription_plans"
end
