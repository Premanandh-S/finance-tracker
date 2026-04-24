# frozen_string_literal: true

class CreatePensionContributions < ActiveRecord::Migration[8.0]
  def change
    create_table :pension_contributions do |t|
      t.bigint :pension_instrument_id, null: false
      t.date :contribution_date, null: false
      t.bigint :amount, null: false
      t.string :contributor_type, null: false

      t.timestamps
    end

    add_index :pension_contributions, :pension_instrument_id,
              name: "index_pension_contributions_on_pension_instrument_id"

    add_index :pension_contributions, [:pension_instrument_id, :contribution_date],
              name: "idx_pension_contributions_on_instrument_id_and_date"

    add_foreign_key :pension_contributions, :pension_instruments, on_delete: :cascade

    add_check_constraint :pension_contributions,
      "amount > 0",
      name: "chk_pension_contributions_amount_positive"

    add_check_constraint :pension_contributions,
      "contributor_type IN ('employee', 'employer', 'self')",
      name: "chk_pension_contributions_contributor_type"
  end
end
