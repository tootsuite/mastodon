# frozen_string_literal: true

class Admin::ActionLogFilter
  KEYS = %i(
    action_type
    account_id
    target_account_id
  ).freeze

  ACTION_TYPE_MAP = {
    assigned_to_self_report: { target_type: 'Report', action: 'assigned_to_self' }.freeze,
    change_email_user: { target_type: 'User', action: 'change_email' }.freeze,
    confirm_user: { target_type: 'User', action: 'confirm' }.freeze,
    create_account_warning: { target_type: 'AccountWarning', action: 'create' }.freeze,
    create_announcement: { target_type: 'Announcement', action: 'create' }.freeze,
    create_custom_emoji: { target_type: 'CustomEmoji', action: 'create' }.freeze,
    create_domain_allow: { target_type: 'DomainAllow', action: 'create' }.freeze,
    create_domain_block: { target_type: 'DomainBlock', action: 'create' }.freeze,
    create_email_domain_block: { target_type: 'EmailDomainBlock', action: 'create' }.freeze,
    create_unavailable_domain: { target_type: 'UnavailableDomain', action: 'create' }.freeze,
    create_registration_filter: { target_type: 'RegistrationFilter', action: 'create' }.freeze,
    demote_user: { target_type: 'User', action: 'demote' }.freeze,
    destroy_announcement: { target_type: 'Announcement', action: 'destroy' }.freeze,
    destroy_custom_emoji: { target_type: 'CustomEmoji', action: 'destroy' }.freeze,
    destroy_domain_allow: { target_type: 'DomainAllow', action: 'destroy' }.freeze,
    destroy_domain_block: { target_type: 'DomainBlock', action: 'destroy' }.freeze,
    destroy_email_domain_block: { target_type: 'EmailDomainBlock', action: 'destroy' }.freeze,
    destroy_unavailable_domain: { target_type: 'UnavailableDomain', action: 'destroy' }.freeze,
    destroy_registration_filter: { target_type: 'RegistrationFilter', action: 'destroy' }.freeze,
    destroy_status: { target_type: 'Status', action: 'destroy' }.freeze,
    disable_2fa_user: { target_type: 'User', action: 'disable' }.freeze,
    disable_custom_emoji: { target_type: 'CustomEmoji', action: 'disable' }.freeze,
    disable_user: { target_type: 'User', action: 'disable' }.freeze,
    enable_custom_emoji: { target_type: 'CustomEmoji', action: 'enable' }.freeze,
    enable_user: { target_type: 'User', action: 'enable' }.freeze,
    memorialize_account: { target_type: 'Account', action: 'memorialize' }.freeze,
    promote_user: { target_type: 'User', action: 'promote' }.freeze,
    remove_avatar_user: { target_type: 'User', action: 'remove_avatar' }.freeze,
    reopen_report: { target_type: 'Report', action: 'reopen' }.freeze,
    reset_password_user: { target_type: 'User', action: 'reset_password' }.freeze,
    resolve_report: { target_type: 'Report', action: 'resolve' }.freeze,
    sensitive_account: { target_type: 'Account', action: 'sensitive' }.freeze,
    silence_account: { target_type: 'Account', action: 'silence' }.freeze,
    suspend_account: { target_type: 'Account', action: 'suspend' }.freeze,
    unassigned_report: { target_type: 'Report', action: 'unassigned' }.freeze,
    unsensitive_account: { target_type: 'Account', action: 'unsensitive' }.freeze,
    unsilence_account: { target_type: 'Account', action: 'unsilence' }.freeze,
    unsuspend_account: { target_type: 'Account', action: 'unsuspend' }.freeze,
    update_announcement: { target_type: 'Announcement', action: 'update' }.freeze,
    update_custom_emoji: { target_type: 'CustomEmoji', action: 'update' }.freeze,
    update_status: { target_type: 'Status', action: 'update' }.freeze,
    update_registration_filter: { target_type: 'RegistrationFilter', action: 'update' }.freeze,
  }.freeze

  attr_reader :params

  def initialize(params)
    @params = params
  end

  def results
    scope = Admin::ActionLog.includes(:target)

    params.each do |key, value|
      next if key.to_s == 'page'

      scope.merge!(scope_for(key.to_s, value.to_s.strip)) if value.present?
    end

    scope
  end

  private

  def scope_for(key, value)
    case key
    when 'action_type'
      Admin::ActionLog.where(ACTION_TYPE_MAP[value.to_sym])
    when 'account_id'
      Admin::ActionLog.where(account_id: value)
    when 'target_account_id'
      account = Account.find(value)
      Admin::ActionLog.where(target: [account, account.user].compact)
    else
      raise "Unknown filter: #{key}"
    end
  end
end
