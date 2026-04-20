class CreateJwtDenylist < ActiveRecord::Migration[8.0]
  def change
    create_table :jwt_denylist do |t|
      t.string :jti, null: false
      t.datetime :exp, null: false
      t.datetime :created_at, null: false
    end

    add_index :jwt_denylist, :jti, unique: true
  end
end
