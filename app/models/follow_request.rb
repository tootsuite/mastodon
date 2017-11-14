# frozen_string_literal: true
# == Schema Information
#
# Table name: follow_requests
#
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  id                :bigint           not null, primary key
#  target_account_id :bigint           not null
#  remote_id         :string
#

class FollowRequest < ApplicationRecord
  include Paginable

  belongs_to :account, required: true
  belongs_to :target_account, class_name: 'Account', required: true

  has_one :notification, as: :activity, dependent: :destroy

  validates :account_id, uniqueness: { scope: :target_account_id }

  def authorize!
    account.follow!(target_account)
    MergeWorker.perform_async(target_account.id, account.id)

    destroy!
  end

  alias reject! destroy!
end
