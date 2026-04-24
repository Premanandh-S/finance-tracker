# frozen_string_literal: true

class CreateInsuredMembers < ActiveRecord::Migration[8.0]
  def change
    create_table :insured_members do |t|
      t.bigint :insurance_policy_id, null: false
      t.string :name, null: false
      t.string :member_identifier

      t.timestamps
    end

    add_index :insured_members, :insurance_policy_id,
              name: "index_insured_members_on_insurance_policy_id"

    add_foreign_key :insured_members, :insurance_policies, on_delete: :cascade
  end
end
