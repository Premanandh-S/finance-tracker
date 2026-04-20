class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :identifier, null: false
      t.string :identifier_type, null: false
      t.string :password_digest
      t.boolean :verified, null: false, default: false
      t.integer :password_failed_attempts, null: false, default: 0
      t.datetime :password_locked_until

      t.timestamps
    end

    add_index :users, :identifier, unique: true

    add_check_constraint :users,
      "identifier_type IN ('phone', 'email')",
      name: "chk_users_identifier_type"
  end
end
