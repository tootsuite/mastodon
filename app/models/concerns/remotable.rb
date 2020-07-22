# frozen_string_literal: true

module Remotable
  extend ActiveSupport::Concern

  included do
    after_save :synchronize_remote_attachments!
  end

  class_methods do
    def remotable_attachment(attachment_name, limit, suppress_errors: true, download_on_assign: true, attribute_name: nil)
      attribute_name ||= "#{attachment_name}_remote_url".to_sym

      define_method("download_#{attachment_name}!") do |url = nil|
        url ||= self[attribute_name]

        return if url.blank?

        begin
          parsed_url = Addressable::URI.parse(url).normalize
        rescue Addressable::URI::InvalidURIError
          return
        end

        return if !%w(http https).include?(parsed_url.scheme) || parsed_url.host.blank?

        # If a file is likely to go through ffmpeg, try the synchronization mechanisms
        needs_synchronization = (MediaAttachment::VIDEO_FILE_EXTENSIONS + ['.gif']).include?(File.extname(parsed_url.basename).downcase)
        processed_url = RemoteSynchronizationManager.instance.get_processed_url(url) if needs_synchronization

        if processed_url == RemoteSynchronizationManager::PROCESSING_VALUE
          raise Mastodon::UnexpectedResponseError unless suppress_errors

          return
        end

        begin
          Request.new(:get, processed_url || url).perform do |response|
            RemoteSynchronizationManager.instance.set_processed_url(url, nil) if processed_url.present? && response.code == 404
            raise Mastodon::UnexpectedResponseError, response unless (200...300).cover?(response.code)

            public_send("#{attachment_name}=", ResponseWithLimit.new(response, limit))
          end
        rescue Mastodon::UnexpectedResponseError, HTTP::TimeoutError, HTTP::ConnectionError, OpenSSL::SSL::SSLError => e
          Rails.logger.debug "Error fetching remote #{attachment_name}: #{e}"
          # We failed processing, release lock on processing media
          RemoteSynchronizationManager.instance.set_processed_url(url, nil) if processed_url.nil? && needs_synchronization
          raise e unless suppress_errors
        rescue Paperclip::Errors::NotIdentifiedByImageMagickError, Addressable::URI::InvalidURIError, Mastodon::HostValidationError, Mastodon::LengthValidationError, Paperclip::Error, Mastodon::DimensionsValidationError, Mastodon::StreamValidationError => e
          Rails.logger.debug "Error fetching remote #{attachment_name}: #{e}"
        end

        # File successfuly processed, get its url
        if processed_url.nil? && needs_synchronization
          @synchronizable_remote_attachments ||= {}
          @synchronizable_remote_attachments[url] = attachment_name
        end

        nil
      end

      define_method("#{attribute_name}=") do |url|
        return if self[attribute_name] == url && public_send("#{attachment_name}_file_name").present?

        self[attribute_name] = url if has_attribute?(attribute_name)

        public_send("download_#{attachment_name}!", url) if download_on_assign
      end

      alias_method("reset_#{attachment_name}!", "download_#{attachment_name}!")
    end
  end

  private

  def synchronize_remote_attachments!
    return unless defined?(@synchronizable_remote_attachments)

    @synchronizable_remote_attachments.each do |url, attachment_name|
      cached_url = public_send(attachment_name).blank? ? nil : public_send(attachment_name).url(:original)
      RemoteSynchronizationManager.instance.set_processed_url(url, cached_url)
    end

    @synchronizable_remote_attachments = {}
  end
end
