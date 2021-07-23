# frozen_string_literal: true

class AccountsController < ApplicationController
  PAGE_SIZE     = 20
  PAGE_SIZE_MAX = 200

  include AccountControllerConcern
  include SignatureAuthentication

  before_action :require_signature!, if: -> { request.format == :json && authorized_fetch_mode? }
  before_action :set_cache_headers
  before_action :set_body_classes

  skip_around_action :set_locale, if: -> { [:json, :rss].include?(request.format&.to_sym) }
  skip_before_action :require_functional!, unless: :whitelist_mode?

  def show
    respond_to do |format|
      format.html do
        expires_in 0, public: true unless user_signed_in?

        @pinned_statuses   = []
        @endorsed_accounts = @account.endorsed_accounts.to_a.sample(4)
        @featured_hashtags = @account.featured_tags.order(statuses_count: :desc)

        if current_account && @account.blocking?(current_account)
          @statuses = []
          return
        end

        @pinned_statuses = cache_collection(@account.pinned_statuses, Status) if show_pinned_statuses?
        @statuses        = cached_filtered_status_page
        @rss_url         = rss_url

        unless @statuses.empty?
          @older_url = older_url if @statuses.last.id > filtered_statuses.last.id
          @newer_url = newer_url if @statuses.first.id < filtered_statuses.first.id
        end
      end

      format.rss do
        expires_in 1.minute, public: true

        limit     = params[:limit].present? ? [params[:limit].to_i, PAGE_SIZE_MAX].min : PAGE_SIZE
        @statuses = filtered_statuses.without_reblogs.without_local_only.limit(limit)
        @statuses = cache_collection(@statuses, Status)
        render xml: RSS::AccountSerializer.render(@account, @statuses, params[:tag])
      end

      format.json do
        expires_in 3.minutes, public: !(authorized_fetch_mode? && signed_request_account.present?)
        render_with_cache json: @account, content_type: 'application/activity+json', serializer: ActivityPub::ActorSerializer, adapter: ActivityPub::Adapter
      end
    end
  end

  private

  def set_body_classes
    @body_classes = 'with-modals'
  end

  def show_pinned_statuses?
    [replies_requested?, media_requested?, tag_requested?, params[:max_id].present?, params[:min_id].present?].none?
  end

  def filtered_statuses
    default_statuses.tap do |statuses|
      statuses.merge!(hashtag_scope)    if tag_requested?
      statuses.merge!(only_media_scope) if media_requested?
      statuses.merge!(no_replies_scope) unless replies_requested?
    end
  end

  def default_statuses
    if current_user.nil?
      @account.statuses.without_local_only.where(visibility: [:public, :unlisted])
    else
      @account.statuses.where(visibility: [:public, :unlisted])
    end
  end

  def only_media_scope
    Status.joins(:media_attachments).merge(@account.media_attachments.reorder(nil)).group(:id)
  end

  def no_replies_scope
    Status.without_replies
  end

  def hashtag_scope
    tag = Tag.find_normalized(params[:tag])

    if tag
      Status.tagged_with(tag.id)
    else
      Status.none
    end
  end

  def username_param
    params[:username]
  end

  def skip_temporary_suspension_response?
    request.format == :json
  end

  def rss_url
    if tag_requested?
      short_account_tag_url(@account, params[:tag], format: 'rss')
    else
      short_account_url(@account, format: 'rss')
    end
  end

  def older_url
    pagination_url(max_id: @statuses.last.id)
  end

  def newer_url
    pagination_url(min_id: @statuses.first.id)
  end

  def pagination_url(max_id: nil, min_id: nil)
    if tag_requested?
      short_account_tag_url(@account, params[:tag], max_id: max_id, min_id: min_id)
    elsif media_requested?
      short_account_media_url(@account, max_id: max_id, min_id: min_id)
    elsif replies_requested?
      short_account_with_replies_url(@account, max_id: max_id, min_id: min_id)
    else
      short_account_url(@account, max_id: max_id, min_id: min_id)
    end
  end

  def media_requested?
    request.path.split('.').first.end_with?('/media') && !tag_requested?
  end

  def replies_requested?
    request.path.split('.').first.end_with?('/with_replies') && !tag_requested?
  end

  def tag_requested?
    request.path.split('.').first.end_with?(Addressable::URI.parse("/tagged/#{params[:tag]}").normalize)
  end

  def cached_filtered_status_page
    cache_collection_paginated_by_id(
      filtered_statuses,
      Status,
      PAGE_SIZE,
      params_slice(:max_id, :min_id, :since_id)
    )
  end

  def params_slice(*keys)
    params.slice(*keys).permit(*keys)
  end
end
