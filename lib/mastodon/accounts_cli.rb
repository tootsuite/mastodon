# frozen_string_literal: true

require 'set'
require_relative '../../config/boot'
require_relative '../../config/environment'
require_relative 'cli_helper'

module Mastodon
  class AccountsCLI < Thor
    include CLIHelper

    def self.exit_on_failure?
      true
    end

    option :all, type: :boolean
    desc 'rotate [USERNAME]', 'Generate and broadcast new keys'
    long_desc <<-LONG_DESC
      Generate and broadcast new RSA keys as part of security
      maintenance.

      With the --all option, all local accounts will be subject
      to the rotation. Otherwise, and by default, only a single
      account specified by the USERNAME argument will be
      processed.
    LONG_DESC
    def rotate(username = nil)
      if options[:all]
        processed = 0
        delay     = 0
        scope     = Account.local.without_suspended
        progress  = create_progress_bar(scope.count)

        scope.find_in_batches do |accounts|
          accounts.each do |account|
            rotate_keys_for_account(account, delay)
            progress.increment
            processed += 1
          end

          delay += 5.minutes
        end

        progress.finish
        say("OK, rotated keys for #{processed} accounts", :green)
      elsif username.present?
        rotate_keys_for_account(Account.find_local(username))
        say('OK', :green)
      else
        say('No account(s) given', :red)
        exit(1)
      end
    end

    option :email, required: true
    option :confirmed, type: :boolean
    option :role, default: 'user', enum: %w(user moderator admin)
    option :skip_sign_in_token, type: :boolean
    option :reattach, type: :boolean
    option :force, type: :boolean
    desc 'create USERNAME', 'Create a new user'
    long_desc <<-LONG_DESC
      Create a new user account with a given USERNAME and an
      e-mail address provided with --email.

      With the --confirmed option, the confirmation e-mail will
      be skipped and the account will be active straight away.

      With the --role option one of  "user", "admin" or "moderator"
      can be supplied. Defaults to "user"

      With the --skip-sign-in-token option, you can ensure that
      the user is never asked for an e-mailed security code.

      With the --reattach option, the new user will be reattached
      to a given existing username of an old account. If the old
      account is still in use by someone else, you can supply
      the --force option to delete the old record and reattach the
      username to the new account anyway.
    LONG_DESC
    def create(username)
      account  = Account.new(username: username)
      password = SecureRandom.hex
      user     = User.new(email: options[:email], password: password, agreement: true, approved: true, admin: options[:role] == 'admin', moderator: options[:role] == 'moderator', confirmed_at: options[:confirmed] ? Time.now.utc : nil, bypass_invite_request_check: true, skip_sign_in_token: options[:skip_sign_in_token])

      if options[:reattach]
        account = Account.find_local(username) || Account.new(username: username)

        if account.user.present? && !options[:force]
          say('The chosen username is currently in use', :red)
          say('Use --force to reattach it anyway and delete the other user')
          return
        elsif account.user.present?
          DeleteAccountService.new.call(account, reserve_email: false)
        end
      end

      account.suspended_at = nil
      user.account         = account

      if user.save
        if options[:confirmed]
          user.confirmed_at = nil
          user.confirm!
        end

        say('OK', :green)
        say("New password: #{password}")
      else
        user.errors.to_h.each do |key, error|
          say('Failure/Error: ', :red)
          say(key)
          say('    ' + error, :red)
        end

        exit(1)
      end
    end

    option :role, enum: %w(user moderator admin)
    option :email
    option :confirm, type: :boolean
    option :enable, type: :boolean
    option :disable, type: :boolean
    option :disable_2fa, type: :boolean
    option :approve, type: :boolean
    option :reset_password, type: :boolean
    option :skip_sign_in_token, type: :boolean
    desc 'modify USERNAME', 'Modify a user'
    long_desc <<-LONG_DESC
      Modify a user account.

      With the --role option, update the user's role to one of "user",
      "moderator" or "admin".

      With the --email option, update the user's e-mail address. With
      the --confirm option, mark the user's e-mail as confirmed.

      With the --disable option, lock the user out of their account. The
      --enable option is the opposite.

      With the --approve option, the account will be approved, if it was
      previously not due to not having open registrations.

      With the --disable-2fa option, the two-factor authentication
      requirement for the user can be removed.

      With the --reset-password option, the user's password is replaced by
      a randomly-generated one, printed in the output.

      With the --skip-sign-in-token option, you can ensure that
      the user is never asked for an e-mailed security code.
    LONG_DESC
    def modify(username)
      user = Account.find_local(username)&.user

      if user.nil?
        say('No user with such username', :red)
        exit(1)
      end

      if options[:role]
        user.admin = options[:role] == 'admin'
        user.moderator = options[:role] == 'moderator'
      end

      password = SecureRandom.hex if options[:reset_password]
      user.password = password if options[:reset_password]
      user.email = options[:email] if options[:email]
      user.disabled = false if options[:enable]
      user.disabled = true if options[:disable]
      user.approved = true if options[:approve]
      user.otp_required_for_login = false if options[:disable_2fa]
      user.skip_sign_in_token = options[:skip_sign_in_token] unless options[:skip_sign_in_token].nil?
      user.confirm if options[:confirm]

      if user.save
        say('OK', :green)
        say("New password: #{password}") if options[:reset_password]
      else
        user.errors.to_h.each do |key, error|
          say('Failure/Error: ', :red)
          say(key)
          say('    ' + error, :red)
        end

        exit(1)
      end
    end

    desc 'delete USERNAME', 'Delete a user'
    long_desc <<-LONG_DESC
      Remove a user account with a given USERNAME.
    LONG_DESC
    def delete(username)
      account = Account.find_local(username)

      if account.nil?
        say('No user with such username', :red)
        exit(1)
      end

      say("Deleting user with #{account.statuses_count} statuses, this might take a while...")
      DeleteAccountService.new.call(account, reserve_email: false)
      say('OK', :green)
    end

    option :force, type: :boolean, aliases: [:f], description: 'Override public key check'
    desc 'merge FROM TO', 'Merge two remote accounts into one'
    long_desc <<-LONG_DESC
      Merge two remote accounts specified by their username@domain
      into one, whereby the TO account is the one being merged into
      and kept, while the FROM one is removed. It is primarily meant
      to fix duplicates caused by other servers changing their domain.

      The command by default only works if both accounts have the same
      public key to prevent mistakes. To override this, use the --force.
    LONG_DESC
    def merge(from_acct, to_acct)
      username, domain = from_acct.split('@')
      from_account = Account.find_remote(username, domain)

      if from_account.nil? || from_account.local?
        say("No such account (#{from_acct})", :red)
        exit(1)
      end

      username, domain = to_acct.split('@')
      to_account = Account.find_remote(username, domain)

      if to_account.nil? || to_account.local?
        say("No such account (#{to_acct})", :red)
        exit(1)
      end

      if from_account.public_key != to_account.public_key && !options[:force]
        say("Accounts don't have the same public key, might not be duplicates!", :red)
        say('Override with --force', :red)
        exit(1)
      end

      to_account.merge_with!(from_account)
      from_account.destroy

      say('OK', :green)
    end

    desc 'fix-duplicates', 'Find duplicate remote accounts and merge them'
    option :dry_run, type: :boolean
    long_desc <<-LONG_DESC
      Merge known remote accounts sharing an ActivityPub actor identifier.

      Such duplicates can occur when a remote server admin misconfigures their
      domain configuration.
    LONG_DESC
    def fix_duplicates
      Account.remote.select(:uri, 'count(*)').group(:uri).having('count(*) > 1').pluck(:uri).each do |uri|
        say("Duplicates found for #{uri}")
        begin
          ActivityPub::FetchRemoteAccountService.new.call(uri) unless options[:dry_run]
        rescue => e
          say("Error processing #{uri}: #{e}", :red)
        end
      end
    end

    desc 'backup USERNAME', 'Request a backup for a user'
    long_desc <<-LONG_DESC
      Request a new backup for an account with a given USERNAME.

      The backup will be created in Sidekiq asynchronously, and
      the user will receive an e-mail with a link to it once
      it's done.
    LONG_DESC
    def backup(username)
      account = Account.find_local(username)

      if account.nil?
        say('No user with such username', :red)
        exit(1)
      end

      backup = account.user.backups.create!
      BackupWorker.perform_async(backup.id)
      say('OK', :green)
    end

    option :concurrency, type: :numeric, default: 5, aliases: [:c]
    option :dry_run, type: :boolean
    desc 'cull', 'Remove remote accounts that no longer exist'
    long_desc <<-LONG_DESC
      Query every single remote account in the database to determine
      if it still exists on the origin server, and if it doesn't,
      remove it from the database.

      Accounts that have had confirmed activity within the last week
      are excluded from the checks.
    LONG_DESC
    def cull
      skip_threshold = 7.days.ago
      dry_run        = options[:dry_run] ? ' (DRY RUN)' : ''
      skip_domains   = Concurrent::Set.new

      processed, culled = parallelize_with_progress(Account.remote.where(protocol: :activitypub).partitioned) do |account|
        next if account.updated_at >= skip_threshold || (account.last_webfingered_at.present? && account.last_webfingered_at >= skip_threshold) || skip_domains.include?(account.domain)

        code = 0

        begin
          code = Request.new(:head, account.uri).perform(&:code)
        rescue HTTP::TimeoutError, HTTP::ConnectionError, OpenSSL::SSL::SSLError
          skip_domains << account.domain
        end

        if [404, 410].include?(code)
          DeleteAccountService.new.call(account, reserve_username: false) unless options[:dry_run]
          1
        else
          # Touch account even during dry run to avoid getting the account into the window again
          account.touch
        end
      end

      say("Visited #{processed} accounts, removed #{culled}#{dry_run}", :green)

      unless skip_domains.empty?
        say('The following domains were not available during the check:', :yellow)
        skip_domains.each { |domain| say('    ' + domain) }
      end
    end

    option :all, type: :boolean
    option :domain
    option :concurrency, type: :numeric, default: 5, aliases: [:c]
    option :verbose, type: :boolean, aliases: [:v]
    option :dry_run, type: :boolean
    desc 'refresh [USERNAME]', 'Fetch remote user data and files'
    long_desc <<-LONG_DESC
      Fetch remote user data and files for one or multiple accounts.

      With the --all option, all remote accounts will be processed.
      Through the --domain option, this can be narrowed down to a
      specific domain only. Otherwise, a single remote account must
      be specified with USERNAME.
    LONG_DESC
    def refresh(username = nil)
      dry_run = options[:dry_run] ? ' (DRY RUN)' : ''

      if options[:domain] || options[:all]
        scope  = Account.remote
        scope  = scope.where(domain: options[:domain]) if options[:domain]

        processed, = parallelize_with_progress(scope) do |account|
          next if options[:dry_run]

          account.reset_avatar!
          account.reset_header!
          account.save
        end

        say("Refreshed #{processed} accounts#{dry_run}", :green, true)
      elsif username.present?
        username, domain = username.split('@')
        account = Account.find_remote(username, domain)

        if account.nil?
          say('No such account', :red)
          exit(1)
        end

        unless options[:dry_run]
          account.reset_avatar!
          account.reset_header!
          account.save
        end

        say("OK#{dry_run}", :green)
      else
        say('No account(s) given', :red)
        exit(1)
      end
    end

    option :concurrency, type: :numeric, default: 5, aliases: [:c]
    option :verbose, type: :boolean, aliases: [:v]
    desc 'follow USERNAME', 'Make all local accounts follow account specified by USERNAME'
    def follow(username)
      target_account = Account.find_local(username)

      if target_account.nil?
        say('No such account', :red)
        exit(1)
      end

      processed, = parallelize_with_progress(Account.local.without_suspended) do |account|
        FollowService.new.call(account, target_account, bypass_limit: true)
      end

      say("OK, followed target from #{processed} accounts", :green)
    end

    option :concurrency, type: :numeric, default: 5, aliases: [:c]
    option :verbose, type: :boolean, aliases: [:v]
    desc 'unfollow ACCT', 'Make all local accounts unfollow account specified by ACCT'
    def unfollow(acct)
      username, domain = acct.split('@')
      target_account = Account.find_remote(username, domain)

      if target_account.nil?
        say('No such account', :red)
        exit(1)
      end

      processed, = parallelize_with_progress(target_account.followers.local) do |account|
        UnfollowService.new.call(account, target_account)
      end

      say("OK, unfollowed target from #{processed} accounts", :green)
    end

    option :follows, type: :boolean, default: false
    option :followers, type: :boolean, default: false
    desc 'reset-relationships USERNAME', 'Reset all follows and/or followers for a user'
    long_desc <<-LONG_DESC
      Reset all follows and/or followers for a user specified by USERNAME.

      With the --follows option, the command unfollows everyone that the account follows,
      and then re-follows the users that would be followed by a brand new account.

      With the --followers option, the command removes all followers of the account.
    LONG_DESC
    def reset_relationships(username)
      unless options[:follows] || options[:followers]
        say('Please specify either --follows or --followers, or both', :red)
        exit(1)
      end

      account = Account.find_local(username)

      if account.nil?
        say('No such account', :red)
        exit(1)
      end

      total     = 0
      total    += Account.where(id: ::Follow.where(account: account).select(:target_account_id)).count if options[:follows]
      total    += Account.where(id: ::Follow.where(target_account: account).select(:account_id)).count if options[:followers]
      progress  = create_progress_bar(total)
      processed = 0

      if options[:follows]
        scope = Account.where(id: ::Follow.where(account: account).select(:target_account_id))

        scope.find_each do |target_account|
          begin
            UnfollowService.new.call(account, target_account)
          rescue => e
            progress.log pastel.red("Error processing #{target_account.id}: #{e}")
          ensure
            progress.increment
            processed += 1
          end
        end

        BootstrapTimelineWorker.perform_async(account.id)
      end

      if options[:followers]
        scope = Account.where(id: ::Follow.where(target_account: account).select(:account_id))

        scope.find_each do |target_account|
          begin
            UnfollowService.new.call(target_account, account)
          rescue => e
            progress.log pastel.red("Error processing #{target_account.id}: #{e}")
          ensure
            progress.increment
            processed += 1
          end
        end
      end

      progress.finish
      say("Processed #{processed} relationships", :green, true)
    end

    option :number, type: :numeric, aliases: [:n]
    option :all, type: :boolean
    desc 'approve [USERNAME]', 'Approve pending accounts'
    long_desc <<~LONG_DESC
      When registrations require review from staff, approve pending accounts,
      either all of them with the --all option, or a specific number of them
      specified with the --number (-n) option, or only a single specific
      account identified by its username.
    LONG_DESC
    def approve(username = nil)
      if options[:all]
        User.pending.find_each(&:approve!)
        say('OK', :green)
      elsif options[:number]
        User.pending.limit(options[:number]).each(&:approve!)
        say('OK', :green)
      elsif username.present?
        account = Account.find_local(username)

        if account.nil?
          say('No such account', :red)
          exit(1)
        end

        account.user&.approve!
        say('OK', :green)
      else
        exit(1)
      end
    end

    private

    def rotate_keys_for_account(account, delay = 0)
      if account.nil?
        say('No such account', :red)
        exit(1)
      end

      old_key = account.private_key
      new_key = OpenSSL::PKey::RSA.new(2048)
      account.update(private_key: new_key.to_pem, public_key: new_key.public_key.to_pem)
      ActivityPub::UpdateDistributionWorker.perform_in(delay, account.id, sign_with: old_key)
    end
  end
end
