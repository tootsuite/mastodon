# frozen_string_literal: true

class RemoveCurrentSignInIpFromUsers < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    safety_assured do
      remove_column :users, :current_sign_in_ip, :inet
      remove_column :users, :last_sign_in_ip, :inet
    end
  end
end
