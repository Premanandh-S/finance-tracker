# frozen_string_literal: true

class CreateInterestRatePeriods < ActiveRecord::Migration[8.0]
  def change
    create_table :interest_rate_periods do |t|
      t.bigint :loan_id, null: false
      t.date :start_date, null: false
      t.date :end_date
      t.decimal :annual_interest_rate, precision: 7, scale: 4, null: false

      t.timestamps
    end

    add_index :interest_rate_periods, :loan_id, name: "index_interest_rate_periods_on_loan_id"
    add_index :interest_rate_periods, [:loan_id, :start_date], name: "index_interest_rate_periods_on_loan_id_and_start_date"

    add_foreign_key :interest_rate_periods, :loans, on_delete: :cascade

    add_check_constraint :interest_rate_periods,
      "annual_interest_rate >= 0 AND annual_interest_rate <= 100",
      name: "chk_interest_rate_periods_annual_interest_rate_range"
  end
end
