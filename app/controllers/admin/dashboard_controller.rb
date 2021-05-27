# frozen_string_literal: true
require 'sidekiq/api'

module Admin
  class DashboardController < BaseController
    def index
      @system_checks         = Admin::SystemCheck.perform
      @users_count           = User.count
      @pending_users_count   = User.pending.count
      @registrations_week    = Redis.current.get("activity:accounts:local:#{current_week}") || 0
      @logins_week           = Redis.current.pfcount("activity:logins:#{current_week}")
      @interactions_week     = Redis.current.get("activity:interactions:#{current_week}") || 0
      @relay_enabled         = Relay.enabled.exists?
      @single_user_mode      = Rails.configuration.x.single_user_mode
      @registrations_enabled = Setting.registrations_mode != 'none'
      @deletions_enabled     = Setting.open_deletion
      @invites_enabled       = Setting.min_invite_role == 'user'
      @search_enabled        = Chewy.enabled?
      @version               = Mastodon::Version.to_s
      @database_version      = ActiveRecord::Base.connection.execute('SELECT VERSION()').first['version'].match(/\A(?:PostgreSQL |)([^\s]+).*\z/)[1]
      @redis_version         = redis_info['redis_version']
      @reports_count         = Report.unresolved.count
      @queue_backlog         = Sidekiq::Stats.new.enqueued
      @recent_users          = User.confirmed.recent.includes(:account).limit(8)
      @database_size         = ActiveRecord::Base.connection.execute('SELECT pg_database_size(current_database())').first['pg_database_size']
      @redis_size            = redis_info['used_memory']
      @ldap_enabled          = ENV['LDAP_ENABLED'] == 'true'
      @cas_enabled           = ENV['CAS_ENABLED'] == 'true'
      @saml_enabled          = ENV['SAML_ENABLED'] == 'true'
      @pam_enabled           = ENV['PAM_ENABLED'] == 'true'
      @openidc_enabled       = ENV['OIDC_ENABLED'] == 'true'
      @hidden_service        = ENV['ALLOW_ACCESS_TO_HIDDEN_SERVICE'] == 'true'
      @trending_hashtags     = TrendingTags.get(10, filtered: false)
      @pending_tags_count    = Tag.pending_review.count
      @authorized_fetch      = authorized_fetch_mode?
      @whitelist_enabled     = whitelist_mode?
      @profile_directory     = Setting.profile_directory
      @timeline_preview      = Setting.timeline_preview
      @trends_enabled        = Setting.trends
    end

    private

    def current_week
      @current_week ||= Time.now.utc.to_date.cweek
    end

    def redis_info
      @redis_info ||= begin
        if Redis.current.is_a?(Redis::Namespace)
          Redis.current.redis.info
        else
          Redis.current.info
        end
      end
    end
  end
end
