# frozen_string_literal: true

require 'tty-prompt'
require_relative '../../config/boot'
require_relative '../../config/environment'
require_relative 'cli_helper'

module Mastodon
  class MaintenanceCLI < Thor
    include CLIHelper

    def self.exit_on_failure?
      true
    end

    MIN_SUPPORTED_VERSION = 2019_10_01_213028
    MAX_SUPPORTED_VERSION = 2021_05_26_193025

    # Stubs to enjoy ActiveRecord queries while not depending on a particular
    # version of the code/database

    class Status < ApplicationRecord; end
    class StatusPin < ApplicationRecord; end
    class Poll < ApplicationRecord; end
    class Report < ApplicationRecord; end
    class Tombstone < ApplicationRecord; end
    class Favourite < ApplicationRecord; end
    class Follow < ApplicationRecord; end
    class FollowRequest < ApplicationRecord; end
    class Block < ApplicationRecord; end
    class Mute < ApplicationRecord; end
    class AccountIdentityProof < ApplicationRecord; end
    class AccountModerationNote < ApplicationRecord; end
    class AccountPin < ApplicationRecord; end
    class ListAccount < ApplicationRecord; end
    class PollVote < ApplicationRecord; end
    class Mention < ApplicationRecord; end
    class AccountDomainBlock < ApplicationRecord; end
    class AnnouncementReaction < ApplicationRecord; end
    class FeaturedTag < ApplicationRecord; end
    class CustomEmoji < ApplicationRecord; end
    class CustomEmojiCategory < ApplicationRecord; end
    class Bookmark < ApplicationRecord; end
    class WebauthnCredential < ApplicationRecord; end
    class FollowRecommendationSuppression < ApplicationRecord; end
    class CanonicalEmailBlock < ApplicationRecord; end

    class PreviewCard < ApplicationRecord
      self.inheritance_column = false
    end

    class MediaAttachment < ApplicationRecord
      self.inheritance_column = nil
    end

    class AccountStat < ApplicationRecord
      belongs_to :account, inverse_of: :account_stat
    end

    # Dummy class, to make migration possible across version changes
    class Account < ApplicationRecord
      has_one :user, inverse_of: :account
      has_one :account_stat, inverse_of: :account

      scope :local, -> { where(domain: nil) }

      def local?
        domain.nil?
      end

      def acct
        local? ? username : "#{username}@#{domain}"
      end

      # This is a duplicate of the AccountMerging concern because we need it to
      # be independent from code version.
      def merge_with!(other_account)
        # Since it's the same remote resource, the remote resource likely
        # already believes we are following/blocking, so it's safe to
        # re-attribute the relationships too. However, during the presence
        # of the index bug users could have *also* followed the reference
        # account already, therefore mass update will not work and we need
        # to check for (and skip past) uniqueness errors

        owned_classes = [
          Status, StatusPin, MediaAttachment, Poll, Report, Tombstone, Favourite,
          Follow, FollowRequest, Block, Mute, AccountIdentityProof,
          AccountModerationNote, AccountPin, AccountStat, ListAccount,
          PollVote, Mention
        ]
        owned_classes << AccountDeletionRequest if ActiveRecord::Base.connection.table_exists?(:account_deletion_requests)
        owned_classes << AccountNote if ActiveRecord::Base.connection.table_exists?(:account_notes)
        owned_classes << FollowRecommendationSuppression if ActiveRecord::Base.connection.table_exists?(:follow_recommendation_suppressions)

        owned_classes.each do |klass|
          klass.where(account_id: other_account.id).find_each do |record|
            begin
              record.update_attribute(:account_id, id)
            rescue ActiveRecord::RecordNotUnique
              next
            end
          end
        end

        target_classes = [Follow, FollowRequest, Block, Mute, AccountModerationNote, AccountPin]
        target_classes << AccountNote if ActiveRecord::Base.connection.table_exists?(:account_notes)

        target_classes.each do |klass|
          klass.where(target_account_id: other_account.id).find_each do |record|
            begin
              record.update_attribute(:target_account_id, id)
            rescue ActiveRecord::RecordNotUnique
              next
            end
          end
        end

        if ActiveRecord::Base.connection.table_exists?(:canonical_email_blocks)
          CanonicalEmailBlock.where(reference_account_id: other_account.id).find_each do |record|
            record.update_attribute(:reference_account_id, id)
          end
        end
      end
    end

    class User < ApplicationRecord
      belongs_to :account, inverse_of: :user
    end

    desc 'fix-duplicates', 'Fix duplicates in database and rebuild indexes'
    long_desc <<~LONG_DESC
      Delete or merge duplicate accounts, statuses, emojis, etc. and rebuild indexes.

      This is useful if your database indexes are corrupted because of issues such as https://wiki.postgresql.org/wiki/Locale_data_changes

      Mastodon has to be stopped to run this task, which will take a long time and may be destructive.
    LONG_DESC
    def fix_duplicates
      @prompt = TTY::Prompt.new

      if ActiveRecord::Migrator.current_version < MIN_SUPPORTED_VERSION
        @prompt.warn 'Your version of the database schema is too old and is not supported by this script.'
        @prompt.warn 'Please update to at least Mastodon 3.0.0 before running this script.'
        exit(1)
      elsif ActiveRecord::Migrator.current_version > MAX_SUPPORTED_VERSION
        @prompt.warn 'Your version of the database schema is more recent than this script, this may cause unexpected errors.'
        exit(1) unless @prompt.yes?('Continue anyway?')
      end

      @prompt.warn 'This task will take a long time to run and is potentially destructive.'
      @prompt.warn 'Please make sure to stop Mastodon and have a backup.'
      exit(1) unless @prompt.yes?('Continue?')

      deduplicate_users!
      deduplicate_account_domain_blocks!
      deduplicate_account_identity_proofs!
      deduplicate_announcement_reactions!
      deduplicate_conversations!
      deduplicate_custom_emojis!
      deduplicate_custom_emoji_categories!
      deduplicate_domain_allows!
      deduplicate_domain_blocks!
      deduplicate_unavailable_domains!
      deduplicate_email_domain_blocks!
      deduplicate_media_attachments!
      deduplicate_preview_cards!
      deduplicate_statuses!
      deduplicate_accounts!
      deduplicate_tags!
      deduplicate_webauthn_credentials!

      Scenic.database.refresh_materialized_view('instances', concurrently: true, cascade: false) if ActiveRecord::Migrator.current_version >= 2020_12_06_004238
      Rails.cache.clear

      @prompt.say 'Finished!'
    end

    MEDIA_TYPES = %w(accounts custom_emojis media_attachments).freeze

    option :domain, type: :string, required: true, desc: 'Target server domain'
    option :only, type: :array, enum: MEDIA_TYPES, desc: 'Only process these media types'
    option :force, type: :boolean, desc: 'Skip new remote_url check'
    desc 'fix-remote-url FROM TO', 'Fix remote_url of existing media'
    long_desc <<-DESC
      Fix the remote_url of the existing media when the remote media server is changed.

      It will automatically check if the media can be obtained from the changed URL. To avoid this, specify the --force option.
    DESC
    def fix_remote_url(from, to)
      @prompt = TTY::Prompt.new

      @from   = from
      @to     = to
      @domain = options[:domain]
      @types  = options[:only] || MEDIA_TYPES
      @force  = options[:force]

      @prompt.say "Start fixing the remote_url of #{@types.join ', '} on the remote server \"#{@domain}\" from \"#{@from}\" to \"#{@to}\"."
      exit(1) unless @prompt.yes?('Continue?') # skipcq: RB-RL1021

      fix_accounts_remote_url!
      fix_custom_emojis_remote_url!
      fix_media_attachments_remote_url!

      Rails.cache.clear

      @prompt.say 'Finished!'
    end

    private

    def fix_accounts_remote_url!
      return unless @types.include? 'accounts'

      @prompt.say 'Fixing accounts…'

      unless @force
        accounts_avatar_remote_url = ::Account.where(domain: @domain).where('avatar_remote_url like ?', "#{@from}%").reorder(avatar_updated_at: :desc).first&.avatar_remote_url&.sub(/^#{@from}/, @to)
        return @prompt.warn  'Skipping because no corresponding remote avatar image could be found.' unless accounts_avatar_remote_url
        return @prompt.error 'The remote avatar image cannot be reached with the changed URL.'       unless reachable_url?(accounts_avatar_remote_url)
      end

      fixed_avatars = ActiveRecord::Base.connection.exec_update(<<-SQL.squish, 'SQL', [[nil, @domain], [nil, @from], [nil, @to], [nil, "#{@from}%"]])
        WITH new AS (
          SELECT
              id,
              replace(avatar_remote_url, $2, $3) AS avatar_remote_url
          FROM
              accounts c
          WHERE
              domain = $1
              AND avatar_remote_url LIKE $4)
        UPDATE
            accounts
        SET
            avatar_remote_url = new.avatar_remote_url
        FROM
            new
        WHERE
            accounts.id = new.id
      SQL
      fixed_headers = ActiveRecord::Base.connection.exec_update(<<-SQL.squish, 'SQL', [[nil, @domain], [nil, @from], [nil, @to], [nil, "#{@from}%"]])
        WITH new AS (
          SELECT
              id,
              replace(header_remote_url, $2, $3) AS header_remote_url
          FROM
              accounts c
          WHERE
              domain = $1
              AND header_remote_url LIKE $4)
        UPDATE
            accounts
        SET
            header_remote_url = new.header_remote_url
        FROM
            new
        WHERE
            accounts.id = new.id
      SQL
      @prompt.ok "Fixed #{fixed_avatars} avatars, #{fixed_headers} headers"
    end

    def fix_custom_emojis_remote_url!
      return unless @types.include? 'custom_emojis'

      @prompt.say 'Fixing custon emojis…'

      unless @force
        custom_emojis_image_remote_url = ::CustomEmoji.where(domain: @domain).where('image_remote_url like ?', "#{@from}%").reorder(image_updated_at: :desc).first&.image_remote_url&.sub(/^#{@from}/, @to)

        return @prompt.warn  'Skipping because no corresponding remote custom emoji could be found.' unless custom_emojis_image_remote_url
        return @prompt.error 'The remote custom emoji cannot be reached with the modified URL.'      unless reachable_url?(custom_emojis_image_remote_url)
      end

      fixed_emojis = ActiveRecord::Base.connection.exec_update(<<-SQL.squish, 'SQL', [[nil, @domain], [nil, @from], [nil, @to], [nil, "#{@from}%"]])
        WITH new AS (
          SELECT
              id,
              replace(image_remote_url, $2, $3) AS image_remote_url
          FROM
              custom_emojis c
          WHERE
              domain = $1
              AND image_remote_url LIKE $4)
        UPDATE
            custom_emojis
        SET
            image_remote_url = new.image_remote_url
        FROM
            new
        WHERE
            custom_emojis.id = new.id
      SQL
      @prompt.ok "Fixed #{fixed_emojis} custom emojis"
    end

    def fix_media_attachments_remote_url!
      return unless @types.include? 'media_attachments'

      @prompt.say 'Fixing media attachments…'

      unless @force
        attatchments_remote_url = ::MediaAttachment.joins(status: :account).where(statuses: { accounts: { domain: @domain } }).where('remote_url like ?', "#{@from}%").reorder(file_updated_at: :desc).first&.remote_url&.sub(/^#{@from}/, @to)

        return @prompt.warn  'Skipping because no corresponding remote media attachment could be found.' unless attatchments_remote_url
        return @prompt.error 'The remote media attachment cannot be reached with the modified URL.'      unless reachable_url?(attatchments_remote_url)
      end

      fixed_attachments = ActiveRecord::Base.connection.exec_update(<<-SQL.squish, 'SQL', [[nil, @domain], [nil, @from], [nil, @to], [nil, "#{@from}%"]])
        WITH new AS (
          SELECT
              m.id,
              replace(m.remote_url, $2, $3) AS remote_url,
              replace(m.thumbnail_remote_url, $2, $3) AS thumbnail_remote_url
          FROM
              media_attachments m
              INNER JOIN statuses s ON m.status_id = s.id
                  AND s.deleted_at IS NULL
                  INNER JOIN accounts a ON s.account_id = a.id
              WHERE
                  a.domain = $1
                  AND m.remote_url LIKE $4)
        UPDATE
            media_attachments
        SET
            remote_url = new.remote_url,
            thumbnail_remote_url = new.thumbnail_remote_url
        FROM
            new
        WHERE
            media_attachments.id = new.id;
      SQL
      @prompt.ok "Fixed #{fixed_attachments} media attachments"
    end

    def reachable_url?(url)
      return false if url.blank?

      code = Request.new(:head, url).perform(&:code)
      (200...300).cover?(code)
    rescue HTTP::ConnectionError
      false
    end

    def deduplicate_accounts!
      remove_index_if_exists!(:accounts, 'index_accounts_on_username_and_domain_lower')

      @prompt.say 'Deduplicating accounts… for local accounts, you will be asked to chose which account to keep unchanged.'

      find_duplicate_accounts.each do |row|
        accounts = Account.where(id: row['ids'].split(',')).to_a

        if accounts.first.local?
          deduplicate_local_accounts!(accounts)
        else
          deduplicate_remote_accounts!(accounts)
        end
      end

      @prompt.say 'Restoring index_accounts_on_username_and_domain_lower…'
      if ActiveRecord::Migrator.current_version < 20200620164023
        ActiveRecord::Base.connection.add_index :accounts, 'lower (username), lower(domain)', name: 'index_accounts_on_username_and_domain_lower', unique: true
      else
        ActiveRecord::Base.connection.add_index :accounts, "lower (username), COALESCE(lower(domain), '')", name: 'index_accounts_on_username_and_domain_lower', unique: true
      end

      @prompt.say 'Reindexing textual indexes on accounts…'
      ActiveRecord::Base.connection.execute('REINDEX INDEX search_index;')
      ActiveRecord::Base.connection.execute('REINDEX INDEX index_accounts_on_uri;')
      ActiveRecord::Base.connection.execute('REINDEX INDEX index_accounts_on_url;')
    end

    def deduplicate_users!
      remove_index_if_exists!(:users, 'index_users_on_confirmation_token')
      remove_index_if_exists!(:users, 'index_users_on_email')
      remove_index_if_exists!(:users, 'index_users_on_remember_token')
      remove_index_if_exists!(:users, 'index_users_on_reset_password_token')

      @prompt.say 'Deduplicating user records…'

      # Deduplicating email
      ActiveRecord::Base.connection.select_all("SELECT string_agg(id::text, ',') AS ids FROM users GROUP BY email HAVING count(*) > 1").each do |row|
        users = User.where(id: row['ids'].split(',')).sort_by(&:updated_at).reverse
        ref_user = users.shift
        @prompt.warn "Multiple users registered with e-mail address #{ref_user.email}."
        @prompt.warn "e-mail will be disabled for the following accounts: #{user.map(&:account).map(&:acct).join(', ')}"
        @prompt.warn 'Please reach out to them and set another address with `tootctl account modify` or delete them.'

        i = 0
        users.each do |user|
          user.update!(email: "#{i} " + user.email)
        end
      end

      ActiveRecord::Base.connection.select_all("SELECT string_agg(id::text, ',') AS ids FROM users WHERE confirmation_token IS NOT NULL GROUP BY confirmation_token HAVING count(*) > 1").each do |row|
        users = User.where(id: row['ids'].split(',')).sort_by(&:created_at).reverse.drop(1)
        @prompt.warn "Unsetting confirmation token for those accounts: #{users.map(&:account).map(&:acct).join(', ')}"

        users.each do |user|
          user.update!(confirmation_token: nil)
        end
      end

      ActiveRecord::Base.connection.select_all("SELECT string_agg(id::text, ',') AS ids FROM users WHERE remember_token IS NOT NULL GROUP BY remember_token HAVING count(*) > 1").each do |row|
        users = User.where(id: row['ids'].split(',')).sort_by(&:updated_at).reverse.drop(1)
        @prompt.warn "Unsetting remember token for those accounts: #{users.map(&:account).map(&:acct).join(', ')}"

        users.each do |user|
          user.update!(remember_token: nil)
        end
      end

      ActiveRecord::Base.connection.select_all("SELECT string_agg(id::text, ',') AS ids FROM users WHERE reset_password_token IS NOT NULL GROUP BY reset_password_token HAVING count(*) > 1").each do |row|
        users = User.where(id: row['ids'].split(',')).sort_by(&:updated_at).reverse.drop(1)
        @prompt.warn "Unsetting password reset token for those accounts: #{users.map(&:account).map(&:acct).join(', ')}"

        users.each do |user|
          user.update!(reset_password_token: nil)
        end
      end

      @prompt.say 'Restoring users indexes…'
      ActiveRecord::Base.connection.add_index :users, ['confirmation_token'], name: 'index_users_on_confirmation_token', unique: true
      ActiveRecord::Base.connection.add_index :users, ['email'], name: 'index_users_on_email', unique: true
      ActiveRecord::Base.connection.add_index :users, ['remember_token'], name: 'index_users_on_remember_token', unique: true
      ActiveRecord::Base.connection.add_index :users, ['reset_password_token'], name: 'index_users_on_reset_password_token', unique: true
    end

    def deduplicate_account_domain_blocks!
      remove_index_if_exists!(:account_domain_blocks, 'index_account_domain_blocks_on_account_id_and_domain')

      @prompt.say 'Removing duplicate account domain blocks…'
      ActiveRecord::Base.connection.select_all("SELECT string_agg(id::text, ',') AS ids FROM account_domain_blocks GROUP BY account_id, domain HAVING count(*) > 1").each do |row|
        AccountDomainBlock.where(id: row['ids'].split(',').drop(1)).delete_all
      end

      @prompt.say 'Restoring account domain blocks indexes…'
      ActiveRecord::Base.connection.add_index :account_domain_blocks, ['account_id', 'domain'], name: 'index_account_domain_blocks_on_account_id_and_domain', unique: true
    end

    def deduplicate_account_identity_proofs!
      remove_index_if_exists!(:account_identity_proofs, 'index_account_proofs_on_account_and_provider_and_username')

      @prompt.say 'Removing duplicate account identity proofs…'
      ActiveRecord::Base.connection.select_all("SELECT string_agg(id::text, ',') AS ids FROM account_identity_proofs GROUP BY account_id, provider, provider_username HAVING count(*) > 1").each do |row|
        AccountIdentityProof.where(id: row['ids'].split(',')).sort_by(&:id).reverse.drop(1).each(&:destroy)
      end

      @prompt.say 'Restoring account identity proofs indexes…'
      ActiveRecord::Base.connection.add_index :account_identity_proofs, ['account_id', 'provider', 'provider_username'], name: 'index_account_proofs_on_account_and_provider_and_username', unique: true
    end

    def deduplicate_announcement_reactions!
      return unless ActiveRecord::Base.connection.table_exists?(:announcement_reactions)

      remove_index_if_exists!(:announcement_reactions, 'index_announcement_reactions_on_account_id_and_announcement_id')

      @prompt.say 'Removing duplicate account identity proofs…'
      ActiveRecord::Base.connection.select_all("SELECT string_agg(id::text, ',') AS ids FROM announcement_reactions GROUP BY account_id, announcement_id, name HAVING count(*) > 1").each do |row|
        AnnouncementReaction.where(id: row['ids'].split(',')).sort_by(&:id).reverse.drop(1).each(&:destroy)
      end

      @prompt.say 'Restoring announcement_reactions indexes…'
      ActiveRecord::Base.connection.add_index :announcement_reactions, ['account_id', 'announcement_id', 'name'], name: 'index_announcement_reactions_on_account_id_and_announcement_id', unique: true
    end

    def deduplicate_conversations!
      remove_index_if_exists!(:conversations, 'index_conversations_on_uri')

      @prompt.say 'Deduplicating conversations…'
      ActiveRecord::Base.connection.select_all("SELECT string_agg(id::text, ',') AS ids FROM conversations WHERE uri IS NOT NULL GROUP BY uri HAVING count(*) > 1").each do |row|
        conversations = Conversation.where(id: row['ids'].split(',')).sort_by(&:id).reverse

        ref_conversation = conversations.shift

        conversations.each do |other|
          merge_conversations!(ref_conversation, other)
          other.destroy
        end
      end

      @prompt.say 'Restoring conversations indexes…'
      ActiveRecord::Base.connection.add_index :conversations, ['uri'], name: 'index_conversations_on_uri', unique: true
    end

    def deduplicate_custom_emojis!
      remove_index_if_exists!(:custom_emojis, 'index_custom_emojis_on_shortcode_and_domain')

      @prompt.say 'Deduplicating custom_emojis…'
      ActiveRecord::Base.connection.select_all("SELECT string_agg(id::text, ',') AS ids FROM custom_emojis GROUP BY shortcode, domain HAVING count(*) > 1").each do |row|
        emojis = CustomEmoji.where(id: row['ids'].split(',')).sort_by(&:id).reverse

        ref_emoji = emojis.shift

        emojis.each do |other|
          merge_custom_emojis!(ref_emoji, other)
          other.destroy
        end
      end

      @prompt.say 'Restoring custom_emojis indexes…'
      ActiveRecord::Base.connection.add_index :custom_emojis, ['shortcode', 'domain'], name: 'index_custom_emojis_on_shortcode_and_domain', unique: true
    end

    def deduplicate_custom_emoji_categories!
      remove_index_if_exists!(:custom_emoji_categories, 'index_custom_emoji_categories_on_name')

      @prompt.say 'Deduplicating custom_emoji_categories…'
      ActiveRecord::Base.connection.select_all("SELECT string_agg(id::text, ',') AS ids FROM custom_emoji_categories GROUP BY name HAVING count(*) > 1").each do |row|
        categories = CustomEmojiCategory.where(id: row['ids'].split(',')).sort_by(&:id).reverse

        ref_category = categories.shift

        categories.each do |other|
          merge_custom_emoji_categories!(ref_category, other)
          other.destroy
        end
      end

      @prompt.say 'Restoring custom_emoji_categories indexes…'
      ActiveRecord::Base.connection.add_index :custom_emoji_categories, ['name'], name: 'index_custom_emoji_categories_on_name', unique: true
    end

    def deduplicate_domain_allows!
      remove_index_if_exists!(:domain_allows, 'index_domain_allows_on_domain')

      @prompt.say 'Deduplicating domain_allows…'
      ActiveRecord::Base.connection.select_all("SELECT string_agg(id::text, ',') AS ids FROM domain_allows GROUP BY domain HAVING count(*) > 1").each do |row|
        DomainAllow.where(id: row['ids'].split(',')).sort_by(&:id).reverse.drop(1).each(&:destroy)
      end

      @prompt.say 'Restoring domain_allows indexes…'
      ActiveRecord::Base.connection.add_index :domain_allows, ['domain'], name: 'index_domain_allows_on_domain', unique: true
    end

    def deduplicate_domain_blocks!
      remove_index_if_exists!(:domain_blocks, 'index_domain_blocks_on_domain')

      @prompt.say 'Deduplicating domain_allows…'
      ActiveRecord::Base.connection.select_all("SELECT string_agg(id::text, ',') AS ids FROM domain_blocks GROUP BY domain HAVING count(*) > 1").each do |row|
        domain_blocks = DomainBlock.where(id: row['ids'].split(',')).by_severity.reverse.to_a

        reject_media = domain_blocks.any?(&:reject_media?)
        reject_reports = domain_blocks.any?(&:reject_reports?)

        reference_block = domain_blocks.shift

        private_comment = domain_blocks.reduce(reference_block.private_comment.presence) { |a, b| a || b.private_comment.presence }
        public_comment  = domain_blocks.reduce(reference_block.public_comment.presence)  { |a, b| a || b.public_comment.presence }

        reference_block.update!(reject_media: reject_media, reject_reports: reject_reports, private_comment: private_comment, public_comment: public_comment)

        domain_blocks.each(&:destroy)
      end

      @prompt.say 'Restoring domain_blocks indexes…'
      ActiveRecord::Base.connection.add_index :domain_blocks, ['domain'], name: 'index_domain_blocks_on_domain', unique: true
    end

    def deduplicate_unavailable_domains!
      return unless ActiveRecord::Base.connection.table_exists?(:unavailable_domains)

      remove_index_if_exists!(:unavailable_domains, 'index_unavailable_domains_on_domain')

      @prompt.say 'Deduplicating unavailable_domains…'
      ActiveRecord::Base.connection.select_all("SELECT string_agg(id::text, ',') AS ids FROM unavailable_domains GROUP BY domain HAVING count(*) > 1").each do |row|
        UnavailableDomain.where(id: row['ids'].split(',')).sort_by(&:id).reverse.drop(1).each(&:destroy)
      end

      @prompt.say 'Restoring domain_allows indexes…'
      ActiveRecord::Base.connection.add_index :unavailable_domains, ['domain'], name: 'index_unavailable_domains_on_domain', unique: true
    end

    def deduplicate_email_domain_blocks!
      remove_index_if_exists!(:email_domain_blocks, 'index_email_domain_blocks_on_domain')

      @prompt.say 'Deduplicating email_domain_blocks…'
      ActiveRecord::Base.connection.select_all("SELECT string_agg(id::text, ',') AS ids FROM email_domain_blocks GROUP BY domain HAVING count(*) > 1").each do |row|
        domain_blocks = EmailDomainBlock.where(id: row['ids'].split(',')).sort_by { |b| b.parent.nil? ? 1 : 0 }.to_a
        domain_blocks.drop(1).each(&:destroy)
      end

      @prompt.say 'Restoring email_domain_blocks indexes…'
      ActiveRecord::Base.connection.add_index :email_domain_blocks, ['domain'], name: 'index_email_domain_blocks_on_domain', unique: true
    end

    def deduplicate_media_attachments!
      remove_index_if_exists!(:media_attachments, 'index_media_attachments_on_shortcode')

      @prompt.say 'Deduplicating media_attachments…'
      ActiveRecord::Base.connection.select_all("SELECT string_agg(id::text, ',') AS ids FROM media_attachments WHERE shortcode IS NOT NULL GROUP BY shortcode HAVING count(*) > 1").each do |row|
        MediaAttachment.where(id: row['ids'].split(',').drop(1)).update_all(shortcode: nil)
      end

      @prompt.say 'Restoring media_attachments indexes…'
      ActiveRecord::Base.connection.add_index :media_attachments, ['shortcode'], name: 'index_media_attachments_on_shortcode', unique: true
    end

    def deduplicate_preview_cards!
      remove_index_if_exists!(:preview_cards, 'index_preview_cards_on_url')

      @prompt.say 'Deduplicating preview_cards…'
      ActiveRecord::Base.connection.select_all("SELECT string_agg(id::text, ',') AS ids FROM preview_cards GROUP BY url HAVING count(*) > 1").each do |row|
        PreviewCard.where(id: row['ids'].split(',')).sort_by(&:id).reverse.drop(1).each(&:destroy)
      end

      @prompt.say 'Restoring preview_cards indexes…'
      ActiveRecord::Base.connection.add_index :preview_cards, ['url'], name: 'index_preview_cards_on_url', unique: true
    end

    def deduplicate_statuses!
      remove_index_if_exists!(:statuses, 'index_statuses_on_uri')

      @prompt.say 'Deduplicating statuses…'
      ActiveRecord::Base.connection.select_all("SELECT string_agg(id::text, ',') AS ids FROM statuses WHERE uri IS NOT NULL GROUP BY uri HAVING count(*) > 1").each do |row|
        statuses = Status.where(id: row['ids'].split(',')).sort_by(&:id)
        ref_status = statuses.shift
        statuses.each do |status|
          merge_statuses!(ref_status, status) if status.account_id == ref_status.account_id
          status.destroy
        end
      end

      @prompt.say 'Restoring statuses indexes…'
      ActiveRecord::Base.connection.add_index :statuses, ['uri'], name: 'index_statuses_on_uri', unique: true
    end

    def deduplicate_tags!
      remove_index_if_exists!(:tags, 'index_tags_on_name_lower')

      @prompt.say 'Deduplicating tags…'
      ActiveRecord::Base.connection.select_all("SELECT string_agg(id::text, ',') AS ids FROM tags GROUP BY lower((name)::text) HAVING count(*) > 1").each do |row|
        tags = Tag.where(id: row['ids'].split(',')).sort_by { |t| [t.usable?, t.trendable?, t.listable?].count(false) }
        ref_tag = tags.shift
        tags.each do |tag|
          merge_tags!(ref_tag, tag)
          tag.destroy
        end
      end

      @prompt.say 'Restoring tags indexes…'
      ActiveRecord::Base.connection.add_index :tags, 'lower((name)::text)', name: 'index_tags_on_name_lower', unique: true

      if ActiveRecord::Base.connection.indexes(:tags).any? { |i| i.name == 'index_tags_on_name_lower_btree' }
        @prompt.say 'Reindexing textual indexes on tags…'
        ActiveRecord::Base.connection.execute('REINDEX INDEX index_tags_on_name_lower_btree;')
      end
    end

    def deduplicate_webauthn_credentials!
      return unless ActiveRecord::Base.connection.table_exists?(:webauthn_credentials)

      remove_index_if_exists!(:webauthn_credentials, 'index_webauthn_credentials_on_external_id')

      @prompt.say 'Deduplicating webauthn_credentials…'
      ActiveRecord::Base.connection.select_all("SELECT string_agg(id::text, ',') AS ids FROM webauthn_credentials GROUP BY external_id HAVING count(*) > 1").each do |row|
        WebauthnCredential.where(id: row['ids'].split(',')).sort_by(&:id).reverse.drop(1).each(&:destroy)
      end

      @prompt.say 'Restoring webauthn_credentials indexes…'
      ActiveRecord::Base.connection.add_index :webauthn_credentials, ['external_id'], name: 'index_webauthn_credentials_on_external_id', unique: true
    end

    def deduplicate_local_accounts!(accounts)
      accounts = accounts.sort_by(&:id).reverse

      @prompt.warn "Multiple local accounts were found for username '#{accounts.first.username}'."
      @prompt.warn 'All those accounts are distinct accounts but only the most recently-created one is fully-functionnal.'

      accounts.each_with_index do |account, idx|
        @prompt.say '%2d. %s: created at: %s; updated at: %s; last logged in at: %s; statuses: %5d; last status at: %s' % [idx, account.username, account.created_at, account.updated_at, account.user&.last_sign_in_at&.to_s || 'N/A', account.account_stat&.statuses_count || 0, account.account_stat&.last_status_at || 'N/A']
      end

      @prompt.say 'Please chose the one to keep unchanged, other ones will be automatically renamed.'

      ref_id = @prompt.ask('Account to keep unchanged:') do |q|
        q.required true
        q.default 0
        q.convert :int
      end

      accounts.delete_at(ref_id)

      i = 0
      accounts.each do |account|
        i += 1
        username = account.username + "_#{i}"

        while Account.local.exists?(username: username)
          i += 1
          username = account.username + "_#{i}"
        end

        account.update!(username: username)
      end
    end

    def deduplicate_remote_accounts!(accounts)
      accounts = accounts.sort_by(&:updated_at).reverse

      reference_account = accounts.shift

      accounts.each do |other_account|
        if other_account.public_key == reference_account.public_key
          # The accounts definitely point to the same resource, so
          # it's safe to re-attribute content and relationships
          reference_account.merge_with!(other_account)
        end

        other_account.destroy
      end
    end

    def merge_conversations!(main_conv, duplicate_conv)
      owned_classes = [ConversationMute, AccountConversation]
      owned_classes.each do |klass|
        klass.where(conversation_id: duplicate_conv.id).find_each do |record|
          begin
            record.update_attribute(:account_id, main_conv.id)
          rescue ActiveRecord::RecordNotUnique
            next
          end
        end
      end
    end

    def merge_custom_emojis!(main_emoji, duplicate_emoji)
      owned_classes = [AnnouncementReaction]
      owned_classes.each do |klass|
        klass.where(custom_emoji_id: duplicate_emoji.id).update_all(custom_emoji_id: main_emoji.id)
      end
    end

    def merge_custom_emoji_categories!(main_category, duplicate_category)
      owned_classes = [CustomEmoji]
      owned_classes.each do |klass|
        klass.where(category_id: duplicate_category.id).update_all(category_id: main_category.id)
      end
    end

    def merge_statuses!(main_status, duplicate_status)
      owned_classes = [Favourite, Mention, Poll]
      owned_classes << Bookmark if ActiveRecord::Base.connection.table_exists?(:bookmarks)
      owned_classes.each do |klass|
        klass.where(status_id: duplicate_status.id).find_each do |record|
          begin
            record.update_attribute(:status_id, main_status.id)
          rescue ActiveRecord::RecordNotUnique
            next
          end
        end
      end

      StatusPin.where(account_id: main_status.account_id, status_id: duplicate_status.id).find_each do |record|
        begin
          record.update_attribute(:status_id, main_status.id)
        rescue ActiveRecord::RecordNotUnique
          next
        end
      end

      Status.where(in_reply_to_id: duplicate_status.id).find_each do |record|
        begin
          record.update_attribute(:in_reply_to_id, main_status.id)
        rescue ActiveRecord::RecordNotUnique
          next
        end
      end

      Status.where(reblog_of_id: duplicate_status.id).find_each do |record|
        begin
          record.update_attribute(:reblog_of_id, main_status.id)
        rescue ActiveRecord::RecordNotUnique
          next
        end
      end
    end

    def merge_tags!(main_tag, duplicate_tag)
      [FeaturedTag].each do |klass|
        klass.where(tag_id: duplicate_tag.id).find_each do |record|
          begin
            record.update_attribute(:tag_id, main_tag.id)
          rescue ActiveRecord::RecordNotUnique
            next
          end
        end
      end
    end

    def find_duplicate_accounts
      ActiveRecord::Base.connection.select_all("SELECT string_agg(id::text, ',') AS ids FROM accounts GROUP BY lower(username), COALESCE(lower(domain), '') HAVING count(*) > 1")
    end

    def remove_index_if_exists!(table, name)
      ActiveRecord::Base.connection.remove_index(table, name: name)
    rescue ArgumentError
      nil
    rescue ActiveRecord::StatementInvalid
      nil
    end
  end
end
