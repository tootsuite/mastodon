# frozen_string_literal: true

class ActivityPub::Activity::Create < ActivityPub::Activity
  include ProcessAudience

  def perform
    dereference_object!

    case @object['type']
    when 'EncryptedMessage'
      create_encrypted_message
    else
      create_status
    end
  end

  private

  def create_encrypted_message
    return reject_payload! if invalid_origin?(object_uri) || @options[:delivered_to_account_id].blank?

    target_account = Account.find(@options[:delivered_to_account_id])
    target_device  = target_account.devices.find_by(device_id: @object.dig('to', 'deviceId'))

    return if target_device.nil?

    target_device.encrypted_messages.create!(
      from_account: @account,
      from_device_id: @object.dig('attributedTo', 'deviceId'),
      type: @object['messageType'],
      body: @object['cipherText'],
      digest: @object.dig('digest', 'digestValue'),
      message_franking: message_franking.to_token
    )
  end

  def message_franking
    MessageFranking.new(
      hmac: @object.dig('digest', 'digestValue'),
      original_franking: @object['messageFranking'],
      source_account_id: @account.id,
      target_account_id: @options[:delivered_to_account_id],
      timestamp: Time.now.utc
    )
  end

  def create_status
    return reject_payload! if unsupported_object_type? || invalid_origin?(object_uri) || tombstone_exists? || !related_to_local_activity?

    lock_or_fail("create:#{object_uri}") do
      return if delete_arrived_first?(object_uri) || poll_vote?

      @status = find_existing_status

      if @status.nil?
        process_status
      elsif @options[:delivered_to_account_id].present?
        postprocess_audience_and_deliver
      end
    end

    @status
  end

  def audience_to
    as_array(@object['to'] || @json['to']).map { |x| value_or_id(x) }
  end

  def audience_cc
    as_array(@object['cc'] || @json['cc']).map { |x| value_or_id(x) }
  end

  def process_status
    @tags     = []
    @mentions = []
    @params   = {}

    process_status_params
    process_tags
    process_audience

    ApplicationRecord.transaction do
      @status = Status.create!(@params)
      attach_tags(@status)
    end

    resolve_thread(@status)
    fetch_replies(@status)
    distribute(@status)
    forward_for_reply
  end

  def find_existing_status
    status   = status_from_uri(object_uri)
    status ||= Status.find_by(uri: @object['atomUri']) if @object['atomUri'].present?
    status
  end

  def process_status_params
    @params = begin
      {
        uri: object_uri,
        url: object_url || object_uri,
        account: @account,
        text: text_from_content || '',
        language: detected_language,
        spoiler_text: converted_object_type? ? '' : (text_from_summary || ''),
        created_at: @object['published'],
        override_timestamps: @options[:override_timestamps],
        reply: @object['inReplyTo'].present?,
        sensitive: @account.sensitized? || @object['sensitive'] || false,
        visibility: visibility_from_audience,
        thread: replied_to_status,
        conversation: conversation_from_uri(@object['conversation']),
        media_attachment_ids: process_attachments.take(4).map(&:id),
        poll: process_poll,
      }
    end
  end

  def attach_tags(status)
    @tags.each do |tag|
      status.tags << tag
      tag.use!(@account, status: status, at_time: status.created_at) if status.public_visibility?
    end

    @mentions.each do |mention|
      mention.status = status
      mention.save
    end
  end

  def process_tags
    return if @object['tag'].nil?

    as_array(@object['tag']).each do |tag|
      if equals_or_includes?(tag['type'], 'Hashtag')
        process_hashtag tag
      elsif equals_or_includes?(tag['type'], 'Mention')
        process_mention tag
      elsif equals_or_includes?(tag['type'], 'Emoji')
        process_emoji tag
      end
    end
  end

  def process_hashtag(tag)
    return if tag['name'].blank?

    Tag.find_or_create_by_names(tag['name']) do |hashtag|
      @tags << hashtag unless @tags.include?(hashtag) || !hashtag.valid?
    end
  rescue ActiveRecord::RecordInvalid
    nil
  end

  def process_mention(tag)
    return if tag['href'].blank?

    account = account_from_uri(tag['href'])
    account = ActivityPub::FetchRemoteAccountService.new.call(tag['href']) if account.nil?

    return if account.nil?

    @mentions << Mention.new(account: account, silent: false)
  end

  def process_emoji(tag)
    return if skip_download?
    return if tag['name'].blank? || tag['icon'].blank? || tag['icon']['url'].blank?

    shortcode = tag['name'].delete(':')
    image_url = tag['icon']['url']
    uri       = tag['id']
    updated   = tag['updated']
    emoji     = CustomEmoji.find_by(shortcode: shortcode, domain: @account.domain)

    return unless emoji.nil? || image_url != emoji.image_remote_url || (updated && updated >= emoji.updated_at)

    emoji ||= CustomEmoji.new(domain: @account.domain, shortcode: shortcode, uri: uri)
    emoji.image_remote_url = image_url
    emoji.save
  rescue Seahorse::Client::NetworkingError
    nil
  end

  def process_attachments
    return [] if @object['attachment'].nil?

    media_attachments = []

    as_array(@object['attachment']).each do |attachment|
      next if attachment['url'].blank? || media_attachments.size >= 4

      begin
        href             = Addressable::URI.parse(attachment['url']).normalize.to_s
        media_attachment = MediaAttachment.create(account: @account, remote_url: href, thumbnail_remote_url: icon_url_from_attachment(attachment), description: attachment['summary'].presence || attachment['name'].presence, focus: attachment['focalPoint'], blurhash: supported_blurhash?(attachment['blurhash']) ? attachment['blurhash'] : nil)
        media_attachments << media_attachment

        next if unsupported_media_type?(attachment['mediaType']) || skip_download?

        media_attachment.download_file!
        media_attachment.download_thumbnail!
        media_attachment.save
      rescue Mastodon::UnexpectedResponseError, HTTP::TimeoutError, HTTP::ConnectionError, OpenSSL::SSL::SSLError
        RedownloadMediaWorker.perform_in(rand(30..600).seconds, media_attachment.id)
      rescue Seahorse::Client::NetworkingError
        nil
      end
    end

    media_attachments
  rescue Addressable::URI::InvalidURIError => e
    Rails.logger.debug "Invalid URL in attachment: #{e}"
    media_attachments
  end

  def icon_url_from_attachment(attachment)
    url = attachment['icon'].is_a?(Hash) ? attachment['icon']['url'] : attachment['icon']
    Addressable::URI.parse(url).normalize.to_s if url.present?
  rescue Addressable::URI::InvalidURIError
    nil
  end

  def process_poll
    return unless @object['type'] == 'Question' && (@object['anyOf'].is_a?(Array) || @object['oneOf'].is_a?(Array))

    expires_at = begin
      if @object['closed'].is_a?(String)
        @object['closed']
      elsif !@object['closed'].nil? && !@object['closed'].is_a?(FalseClass)
        Time.now.utc
      else
        @object['endTime']
      end
    end

    if @object['anyOf'].is_a?(Array)
      multiple = true
      items    = @object['anyOf']
    else
      multiple = false
      items    = @object['oneOf']
    end

    voters_count = @object['votersCount']

    @account.polls.new(
      multiple: multiple,
      expires_at: expires_at,
      options: items.map { |item| item['name'].presence || item['content'] }.compact,
      cached_tallies: items.map { |item| item.dig('replies', 'totalItems') || 0 },
      voters_count: voters_count
    )
  end

  def poll_vote?
    return false if replied_to_status.nil? || replied_to_status.preloadable_poll.nil? || !replied_to_status.local? || !replied_to_status.preloadable_poll.options.include?(@object['name'])

    poll_vote! unless replied_to_status.preloadable_poll.expired?

    true
  end

  def poll_vote!
    poll = replied_to_status.preloadable_poll
    already_voted = true

    lock_or_fail("vote:#{replied_to_status.poll_id}:#{@account.id}") do
      already_voted = poll.votes.where(account: @account).exists?
      poll.votes.create!(account: @account, choice: poll.options.index(@object['name']), uri: object_uri)
    end

    increment_voters_count! unless already_voted
    ActivityPub::DistributePollUpdateWorker.perform_in(3.minutes, replied_to_status.id) unless replied_to_status.preloadable_poll.hide_totals?
  end

  def resolve_thread(status)
    return unless status.reply? && status.thread.nil? && Request.valid_url?(in_reply_to_uri)

    ThreadResolveWorker.perform_async(status.id, in_reply_to_uri)
  end

  def fetch_replies(status)
    collection = @object['replies']
    return if collection.nil?

    replies = ActivityPub::FetchRepliesService.new.call(status, collection, false)
    return unless replies.nil?

    uri = value_or_id(collection)
    ActivityPub::FetchRepliesWorker.perform_async(status.id, uri) unless uri.nil?
  end

  def conversation_from_uri(uri)
    return nil if uri.nil?
    return Conversation.find_by(id: OStatus::TagManager.instance.unique_tag_to_local_id(uri, 'Conversation')) if OStatus::TagManager.instance.local_id?(uri)

    begin
      Conversation.find_or_create_by!(uri: uri)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      retry
    end
  end

  def replied_to_status
    return @replied_to_status if defined?(@replied_to_status)

    if in_reply_to_uri.blank?
      @replied_to_status = nil
    else
      @replied_to_status   = status_from_uri(in_reply_to_uri)
      @replied_to_status ||= status_from_uri(@object['inReplyToAtomUri']) if @object['inReplyToAtomUri'].present?
      @replied_to_status
    end
  end

  def in_reply_to_uri
    value_or_id(@object['inReplyTo'])
  end

  def text_from_content
    return Formatter.instance.linkify([[text_from_name, text_from_summary.presence].compact.join("\n\n"), object_url || object_uri].join(' ')) if converted_object_type?

    if @object['content'].present?
      @object['content']
    elsif content_language_map?
      @object['contentMap'].values.first
    end
  end

  def text_from_summary
    if @object['summary'].present?
      @object['summary']
    elsif summary_language_map?
      @object['summaryMap'].values.first
    end
  end

  def text_from_name
    if @object['name'].present?
      @object['name']
    elsif name_language_map?
      @object['nameMap'].values.first
    end
  end

  def detected_language
    if content_language_map?
      @object['contentMap'].keys.first
    elsif name_language_map?
      @object['nameMap'].keys.first
    elsif summary_language_map?
      @object['summaryMap'].keys.first
    elsif supported_object_type?
      LanguageDetector.instance.detect(text_from_content, @account)
    end
  end

  def object_url
    return if @object['url'].blank?

    url_candidate = url_to_href(@object['url'], 'text/html')

    if invalid_origin?(url_candidate)
      nil
    else
      url_candidate
    end
  end

  def summary_language_map?
    @object['summaryMap'].is_a?(Hash) && !@object['summaryMap'].empty?
  end

  def content_language_map?
    @object['contentMap'].is_a?(Hash) && !@object['contentMap'].empty?
  end

  def name_language_map?
    @object['nameMap'].is_a?(Hash) && !@object['nameMap'].empty?
  end

  def unsupported_media_type?(mime_type)
    mime_type.present? && !MediaAttachment.supported_mime_types.include?(mime_type)
  end

  def supported_blurhash?(blurhash)
    components = blurhash.blank? ? nil : Blurhash.components(blurhash)
    components.present? && components.none? { |comp| comp > 5 }
  end

  def skip_download?
    return @skip_download if defined?(@skip_download)

    @skip_download ||= DomainBlock.reject_media?(@account.domain)
  end

  def reply_to_local?
    !replied_to_status.nil? && replied_to_status.account.local?
  end

  def related_to_local_activity?
    fetch? || followed_by_local_accounts? || requested_through_relay? ||
      responds_to_followed_account? || addresses_local_accounts?
  end

  def responds_to_followed_account?
    !replied_to_status.nil? && (replied_to_status.account.local? || replied_to_status.account.passive_relationships.exists?)
  end

  def addresses_local_accounts?
    return true if @options[:delivered_to_account_id]

    local_usernames = (audience_to + audience_cc).uniq.select { |uri| ActivityPub::TagManager.instance.local_uri?(uri) }.map { |uri| ActivityPub::TagManager.instance.uri_to_local_id(uri, :username) }

    return false if local_usernames.empty?

    Account.local.where(username: local_usernames).exists?
  end

  def tombstone_exists?
    Tombstone.exists?(uri: object_uri)
  end

  def forward_for_reply
    return unless @status.distributable? && @json['signature'].present? && reply_to_local?

    ActivityPub::RawDistributionWorker.perform_async(Oj.dump(@json), replied_to_status.account_id, [@account.preferred_inbox_url])
  end

  def increment_voters_count!
    poll = replied_to_status.preloadable_poll

    unless poll.voters_count.nil?
      poll.voters_count = poll.voters_count + 1
      poll.save
    end
  rescue ActiveRecord::StaleObjectError
    poll.reload
    retry
  end
end
