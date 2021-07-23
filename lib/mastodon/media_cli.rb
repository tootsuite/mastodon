# frozen_string_literal: true

require_relative '../../config/boot'
require_relative '../../config/environment'
require_relative 'cli_helper'

module Mastodon
  class MediaCLI < Thor
    include ActionView::Helpers::NumberHelper
    include CLIHelper

    def self.exit_on_failure?
      true
    end

    option :days, type: :numeric, default: 7, aliases: [:d]
    option :concurrency, type: :numeric, default: 5, aliases: [:c]
    option :verbose, type: :boolean, default: false, aliases: [:v]
    option :dry_run, type: :boolean, default: false
    desc 'remove', 'Remove remote media files'
    long_desc <<-DESC
      Removes locally cached copies of media attachments from other servers.

      The --days option specifies how old media attachments have to be before
      they are removed. It defaults to 7 days.
    DESC
    def remove
      time_ago = options[:days].days.ago
      dry_run  = options[:dry_run] ? '(DRY RUN)' : ''

      processed, aggregate = parallelize_with_progress(MediaAttachment.cached.where.not(remote_url: '').where('created_at < ?', time_ago)) do |media_attachment|
        next if media_attachment.file.blank?

        size = (media_attachment.file_file_size || 0) + (media_attachment.thumbnail_file_size || 0)

        unless options[:dry_run]
          media_attachment.file.destroy
          media_attachment.thumbnail.destroy
          media_attachment.save
        end

        size
      end

      say("Removed #{processed} media attachments (approx. #{number_to_human_size(aggregate)}) #{dry_run}", :green, true)
    end

    option :start_after
    option :prefix
    option :fix_permissions, type: :boolean, default: false
    option :dry_run, type: :boolean, default: false
    desc 'remove-orphans', 'Scan storage and check for files that do not belong to existing media attachments'
    long_desc <<~LONG_DESC
      Scans file storage for files that do not belong to existing media attachments. Because this operation
      requires iterating over every single file individually, it will be slow.

      Please mind that some storage providers charge for the necessary API requests to list objects.
    LONG_DESC
    def remove_orphans
      progress        = create_progress_bar(nil)
      reclaimed_bytes = 0
      removed         = 0
      dry_run         = options[:dry_run] ? ' (DRY RUN)' : ''
      prefix          = options[:prefix]

      case Paperclip::Attachment.default_options[:storage]
      when :s3
        paperclip_instance = MediaAttachment.new.file
        s3_interface       = paperclip_instance.s3_interface
        s3_permissions     = Paperclip::Attachment.default_options[:s3_permissions]
        bucket             = s3_interface.bucket(Paperclip::Attachment.default_options[:s3_credentials][:bucket])
        last_key           = options[:start_after]

        loop do
          objects = begin
            begin
              bucket.objects(start_after: last_key, prefix: prefix).limit(1000).map { |x| x }
            rescue => e
              progress.log(pastel.red("Error fetching list of files: #{e}"))
              progress.log("If you want to continue from this point, add --start-after=#{last_key} to your command") if last_key
              break
            end
          end

          break if objects.empty?

          last_key   = objects.last.key
          record_map = preload_records_from_mixed_objects(objects)

          objects.each do |object|
            object.acl.put(acl: s3_permissions) if options[:fix_permissions] && !options[:dry_run]

            path_segments = object.key.split('/')
            path_segments.delete('cache')

            unless [7, 10].include?(path_segments.size)
              progress.log(pastel.yellow("Unrecognized file found: #{object.key}"))
              next
            end

            model_name      = path_segments.first.classify
            attachment_name = path_segments[1].singularize
            record_id       = path_segments[2..-2].join.to_i
            file_name       = path_segments.last
            record          = record_map.dig(model_name, record_id)
            attachment      = record&.public_send(attachment_name)

            progress.increment

            next unless attachment.blank? || !attachment.variant?(file_name)

            begin
              object.delete unless options[:dry_run]

              reclaimed_bytes += object.size
              removed += 1

              progress.log("Found and removed orphan: #{object.key}")
            rescue => e
              progress.log(pastel.red("Error processing #{object.key}: #{e}"))
            end
          end
        end
      when :fog
        say('The fog storage driver is not supported for this operation at this time', :red)
        exit(1)
      when :filesystem
        require 'find'

        root_path = ENV.fetch('PAPERCLIP_ROOT_PATH', File.join(':rails_root', 'public', 'system')).gsub(':rails_root', Rails.root.to_s)

        Find.find(File.join(*[root_path, prefix].compact)) do |path|
          next if File.directory?(path)

          key = path.gsub("#{root_path}#{File::SEPARATOR}", '')

          path_segments = key.split(File::SEPARATOR)
          path_segments.delete('cache')

          unless [7, 10].include?(path_segments.size)
            progress.log(pastel.yellow("Unrecognized file found: #{key}"))
            next
          end

          model_name      = path_segments.first.classify
          record_id       = path_segments[2..-2].join.to_i
          attachment_name = path_segments[1].singularize
          file_name       = path_segments.last

          next unless PRELOAD_MODEL_WHITELIST.include?(model_name)

          record     = model_name.constantize.find_by(id: record_id)
          attachment = record&.public_send(attachment_name)

          progress.increment

          next unless attachment.blank? || !attachment.variant?(file_name)

          begin
            size = File.size(path)

            unless options[:dry_run]
              File.delete(path)
              begin
                FileUtils.rmdir(File.dirname(path), parents: true)
              rescue Errno::ENOTEMPTY
                # OK
              end
            end

            reclaimed_bytes += size
            removed += 1

            progress.log("Found and removed orphan: #{key}")
          rescue => e
            progress.log(pastel.red("Error processing #{key}: #{e}"))
          end
        end
      end

      progress.total = progress.progress
      progress.finish

      say("Removed #{removed} orphans (approx. #{number_to_human_size(reclaimed_bytes)})#{dry_run}", :green, true)
    end

    desc 'mark-media-missing', 'Clears references to remote media which has been stored locally'
    long_desc <<~DESC
      Clears references to file and thumbnails stored locally that originated remotely.

      This is useful if you are restoring a backup without the cache and need Mastodon to fetch remote media again.
    DESC
    def mark_media_missing
      MediaAttachment.cached.where.not(remote_url: '').each do |attachment|
        attachment.file.destroy
        attachment.thumbnail.destroy
        attachment.save
      end
    end

    option :account, type: :string
    option :domain, type: :string
    option :status, type: :numeric
    option :concurrency, type: :numeric, default: 5, aliases: [:c]
    option :verbose, type: :boolean, default: false, aliases: [:v]
    option :dry_run, type: :boolean, default: false
    option :force, type: :boolean, default: false
    desc 'refresh', 'Fetch remote media files'
    long_desc <<-DESC
      Re-downloads media attachments from other servers. You must specify the
      source of media attachments with one of the following options:

      Use the --status option to download attachments from a specific status,
      using the status local numeric ID.

      Use the --account option to download attachments from a specific account,
      using username@domain handle of the account.

      Use the --domain option to download attachments from a specific domain.

      By default, attachments that are believed to be already downloaded will
      not be re-downloaded. To force re-download of every URL, use --force.
    DESC
    def refresh
      dry_run = options[:dry_run] ? ' (DRY RUN)' : ''

      if options[:status]
        scope = MediaAttachment.where(status_id: options[:status])
      elsif options[:account]
        username, domain = options[:account].split('@')
        account = Account.find_remote(username, domain)

        if account.nil?
          say('No such account', :red)
          exit(1)
        end

        scope = MediaAttachment.where(account_id: account.id)
      elsif options[:domain]
        scope = MediaAttachment.joins(:account).merge(Account.by_domain_and_subdomains(options[:domain]))
      else
        exit(1)
      end

      processed, aggregate = parallelize_with_progress(scope) do |media_attachment|
        next if media_attachment.remote_url.blank? || (!options[:force] && media_attachment.file_file_name.present?)

        unless options[:dry_run]
          media_attachment.reset_file!
          media_attachment.reset_thumbnail!
          media_attachment.save
        end

        media_attachment.file_file_size + (media_attachment.thumbnail_file_size || 0)
      end

      say("Downloaded #{processed} media attachments (approx. #{number_to_human_size(aggregate)})#{dry_run}", :green, true)
    end

    desc 'usage', 'Calculate disk space consumed by Mastodon'
    def usage
      say("Attachments:\t#{number_to_human_size(MediaAttachment.sum(Arel.sql('COALESCE(file_file_size, 0) + COALESCE(thumbnail_file_size, 0)')))} (#{number_to_human_size(MediaAttachment.where(account: Account.local).sum(Arel.sql('COALESCE(file_file_size, 0) + COALESCE(thumbnail_file_size, 0)')))} local)")
      say("Custom emoji:\t#{number_to_human_size(CustomEmoji.sum(:image_file_size))} (#{number_to_human_size(CustomEmoji.local.sum(:image_file_size))} local)")
      say("Preview cards:\t#{number_to_human_size(PreviewCard.sum(:image_file_size))}")
      say("Avatars:\t#{number_to_human_size(Account.sum(:avatar_file_size))} (#{number_to_human_size(Account.local.sum(:avatar_file_size))} local)")
      say("Headers:\t#{number_to_human_size(Account.sum(:header_file_size))} (#{number_to_human_size(Account.local.sum(:header_file_size))} local)")
      say("Backups:\t#{number_to_human_size(Backup.sum(:dump_file_size))}")
      say("Imports:\t#{number_to_human_size(Import.sum(:data_file_size))}")
      say("Settings:\t#{number_to_human_size(SiteUpload.sum(:file_file_size))}")
    end

    desc 'lookup URL', 'Lookup where media is displayed by passing a media URL'
    def lookup(url)
      path = Addressable::URI.parse(url).path

      path_segments = path.split('/')[2..-1]
      path_segments.delete('cache')

      unless [7, 10].include?(path_segments.size)
        say('Not a media URL', :red)
        exit(1)
      end

      model_name = path_segments.first.classify
      record_id  = path_segments[2..-2].join.to_i

      unless PRELOAD_MODEL_WHITELIST.include?(model_name)
        say("Cannot find corresponding model: #{model_name}", :red)
        exit(1)
      end

      record = model_name.constantize.find_by(id: record_id)
      record = record.status if record.respond_to?(:status)

      unless record
        say('Cannot find corresponding record', :red)
        exit(1)
      end

      display_url = ActivityPub::TagManager.instance.url_for(record)

      if display_url.blank?
        say('No public URL for this type of record', :red)
        exit(1)
      end

      say(display_url, :blue)
    rescue Addressable::URI::InvalidURIError
      say('Invalid URL', :red)
      exit(1)
    end

    private

    PRELOAD_MODEL_WHITELIST = %w(
      Account
      Backup
      CustomEmoji
      Import
      MediaAttachment
      PreviewCard
      SiteUpload
    ).freeze

    def preload_records_from_mixed_objects(objects)
      preload_map = Hash.new { |hash, key| hash[key] = [] }

      objects.map do |object|
        segments = object.key.split('/')
        segments.delete('cache')

        next unless [7, 10].include?(segments.size)

        model_name = segments.first.classify
        record_id  = segments[2..-2].join.to_i

        next unless PRELOAD_MODEL_WHITELIST.include?(model_name)

        preload_map[model_name] << record_id
      end

      preload_map.each_with_object({}) do |(model_name, record_ids), model_map|
        model_map[model_name] = model_name.constantize.where(id: record_ids).index_by(&:id)
      end
    end
  end
end
