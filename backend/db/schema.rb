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

ActiveRecord::Schema[8.1].define(version: 2025_06_01_000005) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "insurance_policies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "institution_name", null: false
    t.text "notes"
    t.string "policy_number", null: false
    t.date "policy_start_date"
    t.string "policy_type", null: false
    t.bigint "premium_amount", null: false
    t.string "premium_frequency", null: false
    t.date "renewal_date", null: false
    t.bigint "sum_assured", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_insurance_policies_on_user_id"
    t.check_constraint "policy_type::text = ANY (ARRAY['term'::character varying, 'health'::character varying, 'auto'::character varying, 'bike'::character varying]::text[])", name: "chk_insurance_policies_policy_type"
    t.check_constraint "premium_amount > 0", name: "chk_insurance_policies_premium_amount_positive"
    t.check_constraint "premium_frequency::text = ANY (ARRAY['monthly'::character varying, 'quarterly'::character varying, 'half_yearly'::character varying, 'annually'::character varying]::text[])", name: "chk_insurance_policies_premium_frequency"
    t.check_constraint "sum_assured > 0", name: "chk_insurance_policies_sum_assured_positive"
  end

  create_table "insured_members", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "insurance_policy_id", null: false
    t.string "member_identifier"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["insurance_policy_id"], name: "index_insured_members_on_insurance_policy_id"
  end

  create_table "interest_rate_periods", force: :cascade do |t|
    t.decimal "annual_interest_rate", precision: 7, scale: 4, null: false
    t.datetime "created_at", null: false
    t.date "end_date"
    t.bigint "loan_id", null: false
    t.date "start_date", null: false
    t.datetime "updated_at", null: false
    t.index ["loan_id", "start_date"], name: "index_interest_rate_periods_on_loan_id_and_start_date"
    t.index ["loan_id"], name: "index_interest_rate_periods_on_loan_id"
    t.check_constraint "annual_interest_rate >= 0::numeric AND annual_interest_rate <= 100::numeric", name: "chk_interest_rate_periods_annual_interest_rate_range"
  end

  create_table "jwt_denylist", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "exp", null: false
    t.string "jti", null: false
    t.index ["jti"], name: "index_jwt_denylist_on_jti", unique: true
  end

  create_table "loans", force: :cascade do |t|
    t.decimal "annual_interest_rate", precision: 7, scale: 4, null: false
    t.datetime "created_at", null: false
    t.string "institution_name", null: false
    t.string "interest_rate_type", null: false
    t.string "loan_identifier", null: false
    t.bigint "monthly_payment", null: false
    t.bigint "outstanding_balance", null: false
    t.integer "payment_due_day", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_loans_on_user_id"
    t.check_constraint "annual_interest_rate >= 0::numeric AND annual_interest_rate <= 100::numeric", name: "chk_loans_annual_interest_rate_range"
    t.check_constraint "interest_rate_type::text = ANY (ARRAY['fixed'::character varying, 'floating'::character varying]::text[])", name: "chk_loans_interest_rate_type"
    t.check_constraint "monthly_payment > 0", name: "chk_loans_monthly_payment_positive"
    t.check_constraint "outstanding_balance > 0", name: "chk_loans_outstanding_balance_positive"
    t.check_constraint "payment_due_day >= 1 AND payment_due_day <= 28", name: "chk_loans_payment_due_day_range"
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

  create_table "pension_contributions", force: :cascade do |t|
    t.bigint "amount", null: false
    t.date "contribution_date", null: false
    t.string "contributor_type", null: false
    t.datetime "created_at", null: false
    t.bigint "pension_instrument_id", null: false
    t.datetime "updated_at", null: false
    t.index ["pension_instrument_id", "contribution_date"], name: "idx_pension_contributions_on_instrument_id_and_date"
    t.index ["pension_instrument_id"], name: "index_pension_contributions_on_pension_instrument_id"
    t.check_constraint "amount > 0", name: "chk_pension_contributions_amount_positive"
    t.check_constraint "contributor_type::text = ANY (ARRAY['employee'::character varying, 'employer'::character varying, 'self'::character varying]::text[])", name: "chk_pension_contributions_contributor_type"
  end

  create_table "pension_instruments", force: :cascade do |t|
    t.date "contribution_start_date"
    t.datetime "created_at", null: false
    t.string "institution_name", null: false
    t.date "maturity_date"
    t.bigint "monthly_contribution_amount"
    t.text "notes"
    t.string "pension_identifier", null: false
    t.string "pension_type", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_pension_instruments_on_user_id"
    t.check_constraint "pension_type::text = ANY (ARRAY['epf'::character varying, 'nps'::character varying, 'other'::character varying]::text[])", name: "chk_pension_instruments_pension_type"
  end

  create_table "savings_instruments", force: :cascade do |t|
    t.decimal "annual_interest_rate", precision: 7, scale: 4, null: false
    t.string "contribution_frequency", null: false
    t.datetime "created_at", null: false
    t.string "institution_name", null: false
    t.date "maturity_date"
    t.text "notes"
    t.bigint "principal_amount", null: false
    t.bigint "recurring_amount"
    t.string "savings_identifier", null: false
    t.string "savings_type", null: false
    t.date "start_date", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_savings_instruments_on_user_id"
    t.check_constraint "annual_interest_rate >= 0::numeric AND annual_interest_rate <= 100::numeric", name: "chk_savings_instruments_annual_interest_rate_range"
    t.check_constraint "contribution_frequency::text = ANY (ARRAY['one_time'::character varying, 'monthly'::character varying, 'quarterly'::character varying, 'annually'::character varying]::text[])", name: "chk_savings_instruments_contribution_frequency"
    t.check_constraint "principal_amount > 0", name: "chk_savings_instruments_principal_amount_positive"
    t.check_constraint "savings_type::text = ANY (ARRAY['fd'::character varying, 'rd'::character varying, 'other'::character varying]::text[])", name: "chk_savings_instruments_savings_type"
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

  add_foreign_key "insurance_policies", "users", on_delete: :cascade
  add_foreign_key "insured_members", "insurance_policies", on_delete: :cascade
  add_foreign_key "interest_rate_periods", "loans", on_delete: :cascade
  add_foreign_key "loans", "users", on_delete: :cascade
  add_foreign_key "otp_codes", "users", on_delete: :cascade
  add_foreign_key "otp_request_logs", "users", on_delete: :cascade
  add_foreign_key "pension_contributions", "pension_instruments", on_delete: :cascade
  add_foreign_key "pension_instruments", "users", on_delete: :cascade
  add_foreign_key "savings_instruments", "users", on_delete: :cascade
end
