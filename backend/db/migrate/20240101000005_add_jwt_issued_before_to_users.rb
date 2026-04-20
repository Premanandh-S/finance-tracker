# frozen_string_literal: true

class AddJwtIssuedBeforeToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :jwt_issued_before, :datetime
  end
end
