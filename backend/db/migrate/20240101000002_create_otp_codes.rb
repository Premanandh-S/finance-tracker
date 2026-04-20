class CreateOtpCodes < ActiveRecord::Migration[8.0]
  def change
    create_table :otp_codes do |t|
      t.bigint :user_id, null: false
      t.string :code_digest, null: false
      t.datetime :expires_at, null: false
      t.boolean :used, null: false, default: false
      t.integer :failed_attempts, null: false, default: 0

      t.timestamps
    end

    add_index :otp_codes, :user_id
    add_foreign_key :otp_codes, :users, on_delete: :cascade
  end
end
