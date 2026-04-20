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

ActiveRecord::Schema[8.1].define(version: 2024_01_01_000005) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "jwt_denylist", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "exp", null: false
    t.string "jti", null: false
    t.index ["jti"], name: "index_jwt_denylist_on_jti", unique: true
  end

  create_table "otp_codes", force: :cascade do |t|
    t.string "code_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "updated_at", null: false
    t.boolean "used", default: false, null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_otp_codes_on_user_id"
  end

  create_table "otp_request_logs", force: :cascade do |t|
    t.datetime "requested_at", default: -> { "now()" }, null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "requested_at"], name: "index_otp_request_logs_on_user_id_and_requested_at"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "identifier", null: false
    t.string "identifier_type", null: false
    t.datetime "jwt_issued_before"
    t.string "password_digest"
    t.integer "password_failed_attempts", default: 0, null: false
    t.datetime "password_locked_until"
    t.datetime "updated_at", null: false
    t.boolean "verified", default: false, null: false
    t.index ["identifier"], name: "index_users_on_identifier", unique: true
    t.check_constraint "identifier_type::text = ANY (ARRAY['phone'::character varying::text, 'email'::character varying::text])", name: "chk_users_identifier_type"
  end

  add_foreign_key "otp_codes", "users", on_delete: :cascade
  add_foreign_key "otp_request_logs", "users", on_delete: :cascade
end
