# frozen_string_literal: true

# == Schema Information
#
# Table name: user_ips
#
#  user_id :bigint(8)        primary key
#  ip      :inet
#  used_at :datetime
#
class UserIP < ApplicationRecord
  self.primary_key = :user_id

  belongs_to :user, foreign_key: :user_id

  def readonly?
    true
  end
end
