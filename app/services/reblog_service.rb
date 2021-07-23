# frozen_string_literal: true

class ReblogService < BaseService
  include Authorization
  include Payloadable

  # Reblog a status and notify its remote author
  # @param [Account] account Account to reblog from
  # @param [Status] reblogged_status Status to be reblogged
  # @param [Hash] options
  # @option [String]  :visibility
  # @option [Boolean] :with_rate_limit
  # @return [Status]
  def call(account, reblogged_status, options = {})
    reblogged_status = reblogged_status.reblog if reblogged_status.reblog?

    authorize_with account, reblogged_status, :reblog?

    reblog = account.statuses.find_by(reblog: reblogged_status)

    return reblog unless reblog.nil?

    visibility = begin
      if reblogged_status.hidden?
        reblogged_status.visibility
      else
        options[:visibility] || account.user&.setting_default_privacy
      end
    end

    reblog = account.statuses.create!(reblog: reblogged_status, text: '', visibility: visibility, rate_limit: options[:with_rate_limit])

    DistributionWorker.perform_async(reblog.id)
    unless reblogged_status.local_only?
      ActivityPub::DistributionWorker.perform_async(reblog.id)
    end

    create_notification(reblog)
    bump_potential_friendship(account, reblog)
    record_use(account, reblog)

    reblog
  end

  private

  def create_notification(reblog)
    reblogged_status = reblog.reblog

    if reblogged_status.account.local?
      LocalNotificationWorker.perform_async(reblogged_status.account_id, reblog.id, reblog.class.name, :reblog)
    elsif reblogged_status.account.activitypub? && !reblogged_status.account.following?(reblog.account)
      ActivityPub::DeliveryWorker.perform_async(build_json(reblog), reblog.account_id, reblogged_status.account.inbox_url)
    end
  end

  def bump_potential_friendship(account, reblog)
    ActivityTracker.increment('activity:interactions')

    return if account.following?(reblog.reblog.account_id)

    PotentialFriendshipTracker.record(account.id, reblog.reblog.account_id, :reblog)
  end

  def record_use(account, reblog)
    return unless reblog.public_visibility?

    original_status = reblog.reblog

    original_status.tags.each do |tag|
      tag.use!(account)
    end
  end

  def build_json(reblog)
    Oj.dump(serialize_payload(ActivityPub::ActivityPresenter.from_status(reblog), ActivityPub::ActivitySerializer, signer: reblog.account))
  end
end
