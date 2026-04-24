# frozen_string_literal: true

class CreateSavingsInstruments < ActiveRecord::Migration[8.0]
  def change
    create_table :savings_instruments do |t|
      t.bigint :user_id, null: false
      t.string :institution_name, null: false
      t.string :savings_identifier, null: false
      t.string :savings_type, null: false
      t.bigint :principal_amount, null: false
      t.decimal :annual_interest_rate, precision: 7, scale: 4, null: false
      t.string :contribution_frequency, null: false
      t.date :start_date, null: false
      t.date :maturity_date
      t.bigint :recurring_amount
      t.text :notes

      t.timestamps
    end

    add_index :savings_instruments, :user_id, name: "index_savings_instruments_on_user_id"

    add_foreign_key :savings_instruments, :users, on_delete: :cascade

    add_check_constraint :savings_instruments,
      "savings_type IN ('fd', 'rd', 'other')",
      name: "chk_savings_instruments_savings_type"

    add_check_constraint :savings_instruments,
      "principal_amount > 0",
      name: "chk_savings_instruments_principal_amount_positive"

    add_check_constraint :savings_instruments,
      "annual_interest_rate >= 0 AND annual_interest_rate <= 100",
      name: "chk_savings_instruments_annual_interest_rate_range"

    add_check_constraint :savings_instruments,
      "contribution_frequency IN ('one_time', 'monthly', 'quarterly', 'annually')",
      name: "chk_savings_instruments_contribution_frequency"
  end
end
