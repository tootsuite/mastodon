# frozen_string_literal: true

SimpleNavigation::Configuration.run do |navigation|
  navigation.items do |n|
    n.item :web, safe_join([fa_icon('chevron-left fw'), t('settings.back')]), root_url

    n.item :profile, safe_join([fa_icon('user fw'), t('settings.profile')]), settings_profile_url, if: -> { current_user.functional? } do |s|
      s.item :profile, safe_join([fa_icon('pencil fw'), t('settings.appearance')]), settings_profile_url
      s.item :featured_tags, safe_join([fa_icon('hashtag fw'), t('settings.featured_tags')]), settings_featured_tags_url
      s.item :identity_proofs, safe_join([fa_icon('key fw'), t('settings.identity_proofs')]), settings_identity_proofs_path, highlights_on: %r{/settings/identity_proofs*}, if: proc { current_account.identity_proofs.exists? }
    end

    n.item :preferences, safe_join([fa_icon('cog fw'), t('settings.preferences')]), settings_preferences_url, if: -> { current_user.functional? } do |s|
      s.item :appearance, safe_join([fa_icon('desktop fw'), t('settings.appearance')]), settings_preferences_appearance_url
      s.item :notifications, safe_join([fa_icon('bell fw'), t('settings.notifications')]), settings_preferences_notifications_url
      s.item :other, safe_join([fa_icon('cog fw'), t('preferences.other')]), settings_preferences_other_url
    end

    n.item :relationships, safe_join([fa_icon('users fw'), t('settings.relationships')]), relationships_url, if: -> { current_user.functional? }
    n.item :filters, safe_join([fa_icon('filter fw'), t('filters.index.title')]), filters_path, highlights_on: %r{/filters}, if: -> { current_user.functional? }

    n.item :security, safe_join([fa_icon('lock fw'), t('settings.account')]), edit_user_registration_url do |s|
      s.item :password, safe_join([fa_icon('lock fw'), t('settings.account_settings')]), edit_user_registration_url, highlights_on: %r{/auth/edit|/settings/delete|/settings/migration|/settings/aliases|/settings/login_activities}
      s.item :two_factor_authentication, safe_join([fa_icon('mobile fw'), t('settings.two_factor_authentication')]), settings_two_factor_authentication_methods_url, highlights_on: %r{/settings/two_factor_authentication|/settings/otp_authentication|/settings/security_keys}
      s.item :authorized_apps, safe_join([fa_icon('list fw'), t('settings.authorized_apps')]), oauth_authorized_applications_url
    end

    n.item :data, safe_join([fa_icon('cloud-download fw'), t('settings.import_and_export')]), settings_export_url do |s|
      s.item :import, safe_join([fa_icon('cloud-upload fw'), t('settings.import')]), settings_import_url, if: -> { current_user.functional? }
      s.item :export, safe_join([fa_icon('cloud-download fw'), t('settings.export')]), settings_export_url
    end

    n.item :invites, safe_join([fa_icon('user-plus fw'), t('invites.title')]), invites_path, if: proc { Setting.min_invite_role == 'user' && current_user.functional? }
    n.item :development, safe_join([fa_icon('code fw'), t('settings.development')]), settings_applications_url, if: -> { current_user.functional? }

    n.item :moderation, safe_join([fa_icon('gavel fw'), t('moderation.title')]), admin_reports_url, if: proc { current_user.staff? } do |s|
      s.item :action_logs, safe_join([fa_icon('bars fw'), t('admin.action_logs.title')]), admin_action_logs_url
      s.item :reports, safe_join([fa_icon('flag fw'), t('admin.reports.title')]), admin_reports_url, highlights_on: %r{/admin/reports}
      s.item :accounts, safe_join([fa_icon('users fw'), t('admin.accounts.title')]), admin_accounts_url, highlights_on: %r{/admin/accounts|/admin/pending_accounts}
      s.item :invites, safe_join([fa_icon('user-plus fw'), t('admin.invites.title')]), admin_invites_path
      s.item :tags, safe_join([fa_icon('hashtag fw'), t('admin.tags.title')]), admin_tags_path, highlights_on: %r{/admin/tags}
      s.item :follow_recommendations, safe_join([fa_icon('user-plus fw'), t('admin.follow_recommendations.title')]), admin_follow_recommendations_path, highlights_on: %r{/admin/follow_recommendations}
      s.item :instances, safe_join([fa_icon('cloud fw'), t('admin.instances.title')]), admin_instances_url(limited: whitelist_mode? ? nil : '1'), highlights_on: %r{/admin/instances|/admin/domain_blocks|/admin/domain_allows}, if: -> { current_user.admin? }
      s.item :email_domain_blocks, safe_join([fa_icon('envelope fw'), t('admin.email_domain_blocks.title')]), admin_email_domain_blocks_url, highlights_on: %r{/admin/email_domain_blocks}, if: -> { current_user.admin? }
      s.item :ip_blocks, safe_join([fa_icon('ban fw'), t('admin.ip_blocks.title')]), admin_ip_blocks_url, highlights_on: %r{/admin/ip_blocks}, if: -> { current_user.admin? }
      s.item :registration_filters, safe_join([fa_icon('filter fw'), t('admin.registration_filters.title')]), admin_registration_filters_path, highlights_on: %r{/admin/registration_filters}, if: -> { approved_registrations? }
    end

    n.item :admin, safe_join([fa_icon('cogs fw'), t('admin.title')]), admin_dashboard_url, if: proc { current_user.staff? } do |s|
      s.item :dashboard, safe_join([fa_icon('tachometer fw'), t('admin.dashboard.title')]), admin_dashboard_url
      s.item :settings, safe_join([fa_icon('cogs fw'), t('admin.settings.title')]), edit_admin_settings_url, if: -> { current_user.admin? }, highlights_on: %r{/admin/settings}
      s.item :rules, safe_join([fa_icon('gavel fw'), t('admin.rules.title')]), admin_rules_path, highlights_on: %r{/admin/rules}
      s.item :announcements, safe_join([fa_icon('bullhorn fw'), t('admin.announcements.title')]), admin_announcements_path, highlights_on: %r{/admin/announcements}
      s.item :custom_emojis, safe_join([fa_icon('smile-o fw'), t('admin.custom_emojis.title')]), admin_custom_emojis_url, highlights_on: %r{/admin/custom_emojis}
      s.item :relays, safe_join([fa_icon('exchange fw'), t('admin.relays.title')]), admin_relays_url, if: -> { current_user.admin? && !whitelist_mode? }, highlights_on: %r{/admin/relays}
      s.item :sidekiq, safe_join([fa_icon('diamond fw'), 'Sidekiq']), sidekiq_url, link_html: { target: 'sidekiq' }, if: -> { current_user.admin? }
      s.item :pghero, safe_join([fa_icon('database fw'), 'PgHero']), pghero_url, link_html: { target: 'pghero' }, if: -> { current_user.admin? }
    end

    n.item :logout, safe_join([fa_icon('sign-out fw'), t('auth.logout')]), destroy_user_session_url, link_html: { 'data-method' => 'delete' }
  end
end
