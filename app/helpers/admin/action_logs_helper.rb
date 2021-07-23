# frozen_string_literal: true

module Admin::ActionLogsHelper
  def log_target(log)
    if log.target
      linkable_log_target(log.target)
    else
      log_target_from_history(log.target_type, log.recorded_changes)
    end
  end

  private

  def linkable_log_target(record)
    case record.class.name
    when 'Account'
      link_to record.acct, admin_account_path(record.id)
    when 'User'
      link_to record.account.acct, admin_account_path(record.account_id)
    when 'CustomEmoji'
      record.shortcode
    when 'Report'
      link_to "##{record.id}", admin_report_path(record)
    when 'DomainBlock', 'DomainAllow', 'EmailDomainBlock', 'UnavailableDomain'
      link_to record.domain, "https://#{record.domain}"
    when 'Status'
      link_to record.account.acct, ActivityPub::TagManager.instance.url_for(record)
    when 'AccountWarning'
      link_to record.target_account.acct, admin_account_path(record.target_account_id)
    when 'Announcement'
      link_to truncate(record.text), edit_admin_announcement_path(record.id)
    when 'IpBlock'
      "#{record.ip}/#{record.ip.prefix} (#{I18n.t("simple_form.labels.ip_block.severities.#{record.severity}")})"
    when 'RegistrationFilter'
      link_to "#{truncate(record.phrase)} (#{I18n.t("admin.registration_filters.types.#{record.type}")})", edit_admin_registration_filter_path(record.id)
    end
  end

  def log_target_from_history(type, attributes)
    case type
    when 'CustomEmoji'
      attributes['shortcode']
    when 'DomainBlock', 'DomainAllow', 'EmailDomainBlock', 'UnavailableDomain'
      link_to attributes['domain'], "https://#{attributes['domain']}"
    when 'Status'
      tmp_status = Status.new(attributes.except('reblogs_count', 'favourites_count'))

      if tmp_status.account
        link_to tmp_status.account&.acct || "##{tmp_status.account_id}", admin_account_path(tmp_status.account_id)
      else
        I18n.t('admin.action_logs.deleted_status')
      end
    when 'Announcement'
      truncate(attributes['text'].is_a?(Array) ? attributes['text'].last : attributes['text'])
    when 'IpBlock'
      "#{attributes['ip']}/#{attributes['ip'].prefix} (#{I18n.t("simple_form.labels.ip_block.severities.#{attributes['severity']}")})"
    when 'RegistrationFilter'
      "#{truncate(attributes['phrase'])} (#{I18n.t("admin.registration_filters.types.#{attributes['type']}")})"
    end
  end
end
