# frozen_string_literal: true

class ActivityPub::Activity::Announce < ActivityPub::Activity
  include ProcessAudience

  def perform
    return reject_payload! if delete_arrived_first?(@json['id']) || !related_to_local_activity?

    lock_or_fail("announce:#{@object['id']}") do
      @original_status = status_from_object

      return reject_payload! if @original_status.nil? || !announceable?(@original_status)

      @status = Status.find_by(account: @account, reblog: @original_status)

      if @status.nil?
        process_status
      elsif @options[:delivered_to_account_id].present?
        postprocess_audience_and_deliver
      end
    end

    @status
  end

  private

  def process_status
    @mentions = []
    @params   = {}

    process_status_params
    process_audience

    ApplicationRecord.transaction do
      @status = Status.create!(@params)
      attach_mentions(@status)
    end

    @original_status.tags.each do |tag|
      tag.use!(@account)
    end

    distribute(@status)
  end

  def process_status_params
    @params = begin
      {
        account: @account,
        reblog: @original_status,
        uri: @json['id'],
        created_at: @json['published'],
        override_timestamps: @options[:override_timestamps],
        visibility: visibility_from_audience,
      }
    end
  end

  def attach_mentions(status)
    @mentions.each do |mention|
      mention.status = status
      mention.save
    end
  end

  def announceable?(status)
    status.account_id == @account.id || status.distributable?
  end

  def related_to_local_activity?
    followed_by_local_accounts? || requested_through_relay? || reblog_of_local_status?
  end

  def requested_through_relay?
    super || Relay.find_by(inbox_url: @account.inbox_url)&.enabled?
  end

  def reblog_of_local_status?
    ActivityPub::TagManager.instance.local_uri?(object_uri) && status_from_uri(object_uri)&.account&.local?
  end
end
