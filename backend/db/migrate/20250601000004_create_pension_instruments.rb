# frozen_string_literal: true

class CreatePensionInstruments < ActiveRecord::Migration[8.0]
  def change
    create_table :pension_instruments do |t|
      t.bigint :user_id, null: false
      t.string :institution_name, null: false
      t.string :pension_identifier, null: false
      t.string :pension_type, null: false
      t.bigint :monthly_contribution_amount
      t.date :contribution_start_date
      t.date :maturity_date
      t.text :notes

      t.timestamps
    end

    add_index :pension_instruments, :user_id, name: "index_pension_instruments_on_user_id"

    add_foreign_key :pension_instruments, :users, on_delete: :cascade

    add_check_constraint :pension_instruments,
      "pension_type IN ('epf', 'nps', 'other')",
      name: "chk_pension_instruments_pension_type"
  end
end
