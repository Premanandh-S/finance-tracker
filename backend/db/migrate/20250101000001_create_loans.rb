# frozen_string_literal: true

class CreateLoans < ActiveRecord::Migration[8.0]
  def change
    create_table :loans do |t|
      t.bigint :user_id, null: false
      t.string :institution_name, null: false
      t.string :loan_identifier, null: false
      t.bigint :outstanding_balance, null: false
      t.decimal :annual_interest_rate, precision: 7, scale: 4, null: false
      t.string :interest_rate_type, null: false
      t.bigint :monthly_payment, null: false
      t.integer :payment_due_day, null: false

      t.timestamps
    end

    add_index :loans, :user_id, name: "index_loans_on_user_id"

    add_foreign_key :loans, :users, on_delete: :cascade

    add_check_constraint :loans,
      "outstanding_balance > 0",
      name: "chk_loans_outstanding_balance_positive"

    add_check_constraint :loans,
      "annual_interest_rate >= 0 AND annual_interest_rate <= 100",
      name: "chk_loans_annual_interest_rate_range"

    add_check_constraint :loans,
      "interest_rate_type IN ('fixed', 'floating')",
      name: "chk_loans_interest_rate_type"

    add_check_constraint :loans,
      "monthly_payment > 0",
      name: "chk_loans_monthly_payment_positive"

    add_check_constraint :loans,
      "payment_due_day >= 1 AND payment_due_day <= 28",
      name: "chk_loans_payment_due_day_range"
  end
end
