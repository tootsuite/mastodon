class CreateUserIps < ActiveRecord::Migration[6.1]
  def change
    create_view :user_ips
  end
end
