# frozen_string_literal: true
# == Schema Information
#
# Table name: follows
#
#  id                :bigint(8)        not null, primary key
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint(8)        not null
#  target_account_id :bigint(8)        not null
#  show_reblogs      :boolean          default(TRUE), not null
#

class Follow < ApplicationRecord
  include Paginable
  include RelationshipCacheable

  belongs_to :account, counter_cache: :following_count

  belongs_to :target_account,
             class_name: 'Account',
             counter_cache: :followers_count

  has_one :notification, as: :activity, dependent: :destroy

  validates :account_id, uniqueness: { scope: :target_account_id }

  scope :recent, -> { reorder(id: :desc) }
end
