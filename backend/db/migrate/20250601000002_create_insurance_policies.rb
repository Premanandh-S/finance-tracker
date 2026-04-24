# frozen_string_literal: true

class CreateInsurancePolicies < ActiveRecord::Migration[8.0]
  def change
    create_table :insurance_policies do |t|
      t.bigint :user_id, null: false
      t.string :institution_name, null: false
      t.string :policy_number, null: false
      t.string :policy_type, null: false
      t.bigint :sum_assured, null: false
      t.bigint :premium_amount, null: false
      t.string :premium_frequency, null: false
      t.date :renewal_date, null: false
      t.date :policy_start_date
      t.text :notes

      t.timestamps
    end

    add_index :insurance_policies, :user_id, name: "index_insurance_policies_on_user_id"

    add_foreign_key :insurance_policies, :users, on_delete: :cascade

    add_check_constraint :insurance_policies,
      "policy_type IN ('term', 'health', 'auto', 'bike')",
      name: "chk_insurance_policies_policy_type"

    add_check_constraint :insurance_policies,
      "sum_assured > 0",
      name: "chk_insurance_policies_sum_assured_positive"

    add_check_constraint :insurance_policies,
      "premium_amount > 0",
      name: "chk_insurance_policies_premium_amount_positive"

    add_check_constraint :insurance_policies,
      "premium_frequency IN ('monthly', 'quarterly', 'half_yearly', 'annually')",
      name: "chk_insurance_policies_premium_frequency"
  end
end
