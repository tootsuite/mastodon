# frozen_string_literal: true

module AccountAssociations
  extend ActiveSupport::Concern

  included do
    # Local users
    has_one :user, inverse_of: :account, dependent: :destroy

    # Identity proofs
    has_many :identity_proofs, class_name: 'AccountIdentityProof', dependent: :destroy, inverse_of: :account
    has_many :devices, dependent: :destroy, inverse_of: :account

    # Timelines
    has_many :statuses, inverse_of: :account, dependent: :destroy
    has_many :favourites, inverse_of: :account, dependent: :destroy
    has_many :bookmarks, inverse_of: :account, dependent: :destroy
    has_many :mentions, inverse_of: :account, dependent: :destroy
    has_many :notifications, inverse_of: :account, dependent: :destroy
    has_many :conversations, class_name: 'AccountConversation', dependent: :destroy, inverse_of: :account
    has_many :scheduled_statuses, inverse_of: :account, dependent: :destroy

    # Pinned statuses
    has_many :status_pins, inverse_of: :account, dependent: :destroy
    has_many :pinned_statuses, -> { reorder('status_pins.created_at DESC') }, through: :status_pins, class_name: 'Status', source: :status

    # Endorsements
    has_many :account_pins, inverse_of: :account, dependent: :destroy
    has_many :endorsed_accounts, through: :account_pins, class_name: 'Account', source: :target_account

    # Media
    has_many :media_attachments, dependent: :destroy
    has_many :polls, dependent: :destroy

    # Report relationships
    has_many :reports, dependent: :destroy, inverse_of: :account
    has_many :targeted_reports, class_name: 'Report', foreign_key: :target_account_id, dependent: :destroy, inverse_of: :target_account

    has_many :report_notes, dependent: :destroy
    has_many :custom_filters, inverse_of: :account, dependent: :destroy

    # Moderation notes
    has_many :account_moderation_notes, dependent: :destroy, inverse_of: :account
    has_many :targeted_moderation_notes, class_name: 'AccountModerationNote', foreign_key: :target_account_id, dependent: :destroy, inverse_of: :target_account
    has_many :account_warnings, dependent: :destroy, inverse_of: :account
    has_many :targeted_account_warnings, class_name: 'AccountWarning', foreign_key: :target_account_id, dependent: :destroy, inverse_of: :target_account

    # Lists (that the account is on, not owned by the account)
    has_many :list_accounts, inverse_of: :account, dependent: :destroy
    has_many :lists, through: :list_accounts

    # Lists (owned by the account)
    has_many :owned_lists, class_name: 'List', dependent: :destroy, inverse_of: :account

    # Account migrations
    belongs_to :moved_to_account, class_name: 'Account', optional: true
    has_many :migrations, class_name: 'AccountMigration', dependent: :destroy, inverse_of: :account
    has_many :aliases, class_name: 'AccountAlias', dependent: :destroy, inverse_of: :account

    # Hashtags
    has_and_belongs_to_many :tags
    has_many :featured_tags, -> { includes(:tag) }, dependent: :destroy, inverse_of: :account

    # Account deletion requests
    has_one :deletion_request, class_name: 'AccountDeletionRequest', inverse_of: :account, dependent: :destroy

    # Follow recommendations
    has_one :follow_recommendation_suppression, inverse_of: :account, dependent: :destroy

    # Account statuses cleanup policy
    has_one :statuses_cleanup_policy, class_name: 'AccountStatusesCleanupPolicy', inverse_of: :account, dependent: :destroy
  end
end
