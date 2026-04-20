class CreateOtpRequestLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :otp_request_logs do |t|
      t.bigint :user_id, null: false
      t.datetime :requested_at, null: false, default: -> { "NOW()" }
    end

    add_index :otp_request_logs, [:user_id, :requested_at]
    add_foreign_key :otp_request_logs, :users, on_delete: :cascade
  end
end
