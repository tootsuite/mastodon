# frozen_string_literal: true

module ActivityPub::Activity::ProcessAudience
  extend ActiveSupport::Concern

  private

  def audience_to
    as_array(@json['to']).map { |x| value_or_id(x) }
  end

  def audience_cc
    as_array(@json['cc']).map { |x| value_or_id(x) }
  end

  def process_audience
    (audience_to + audience_cc).uniq.each do |audience|
      next if ActivityPub::TagManager.instance.public_collection?(audience)

      # Unlike with tags, there is no point in resolving accounts we don't already
      # know here, because silent mentions would only be used for local access
      # control anyway
      account = account_from_uri(audience)

      next if account.nil? || @mentions.any? { |mention| mention.account_id == account.id }

      @mentions << Mention.new(account: account, silent: true)

      # If there is at least one silent mention, then the status can be considered
      # as a limited-audience status, and not strictly a direct message, but only
      # if we considered a direct message in the first place
      @params[:visibility] = :limited if @params[:visibility] == :direct
    end

    # If the payload was delivered to a specific inbox, the inbox owner must have
    # access to it, unless they already have access to it anyway
    return if @options[:delivered_to_account_id].nil? || @mentions.any? { |mention| mention.account_id == @options[:delivered_to_account_id] }

    @mentions << Mention.new(account_id: @options[:delivered_to_account_id], silent: true)

    @params[:visibility] = :limited if @params[:visibility] == :direct
  end

  def postprocess_audience_and_deliver
    return if @status.mentions.find_by(account_id: @options[:delivered_to_account_id])

    delivered_to_account = Account.find(@options[:delivered_to_account_id])

    @status.mentions.create(account: delivered_to_account, silent: true)
    @status.update(visibility: :limited) if @status.direct_visibility?

    return unless delivered_to_account.following?(@account)

    FeedInsertWorker.perform_async(@status.id, delivered_to_account.id, :home)
  end

  def visibility_from_audience
    if audience_to.any? { |to| ActivityPub::TagManager.instance.public_collection?(to) }
      :public
    elsif audience_cc.any? { |cc| ActivityPub::TagManager.instance.public_collection?(cc) }
      :unlisted
    elsif audience_to.include?(@account.followers_url)
      :private
    else
      :direct
    end
  end

  def audience_includes?(account)
    uri = ActivityPub::TagManager.instance.uri_for(account)
    audience_to.include?(uri) || audience_cc.include?(uri)
  end
end
