# frozen_string_literal: true

class Form::AdminSettings
  include ActiveModel::Model

  KEYS = %i(
    site_contact_username
    site_contact_email
    site_title
    site_short_description
    site_description
    site_extended_description
    site_terms
    registrations_mode
    closed_registrations_message
    open_deletion
    timeline_preview
    show_staff_badge
    bootstrap_timeline_accounts
    theme
    min_invite_role
    activity_api_enabled
    peers_api_enabled
    show_known_fediverse_at_about_page
    preview_sensitive_media
    custom_css
    profile_directory
    thumbnail
    hero
    mascot
    trends
    trendable_by_default
    show_domain_blocks
    show_domain_blocks_rationale
    noindex
    require_invite_text
  ).freeze

  BOOLEAN_KEYS = %i(
    open_deletion
    timeline_preview
    show_staff_badge
    activity_api_enabled
    peers_api_enabled
    show_known_fediverse_at_about_page
    preview_sensitive_media
    profile_directory
    trends
    trendable_by_default
    noindex
    require_invite_text
  ).freeze

  UPLOAD_KEYS = %i(
    thumbnail
    hero
    mascot
  ).freeze

  attr_accessor(*KEYS)

  validates :site_short_description, :site_description, html: { wrap_with: :p }
  validates :site_extended_description, :site_terms, :closed_registrations_message, html: true
  validates :registrations_mode, inclusion: { in: %w(open approved none) }
  validates :min_invite_role, inclusion: { in: %w(disabled user moderator admin) }
  validates :site_contact_email, :site_contact_username, presence: true
  validates :site_contact_username, existing_username: true
  validates :bootstrap_timeline_accounts, existing_username: { multiple: true }
  validates :show_domain_blocks, inclusion: { in: %w(disabled users all) }
  validates :show_domain_blocks_rationale, inclusion: { in: %w(disabled users all) }

  def initialize(_attributes = {})
    super
    initialize_attributes
  end

  def save
    return false unless valid?

    KEYS.each do |key|
      value = instance_variable_get("@#{key}")

      if UPLOAD_KEYS.include?(key) && !value.nil?
        upload = SiteUpload.where(var: key).first_or_initialize(var: key)
        upload.update(file: value)
      else
        setting = Setting.where(var: key).first_or_initialize(var: key)
        setting.update(value: typecast_value(key, value))
      end
    end

    setting = Setting.where(var: 'settings_version').first_or_initialize(var: 'settings_version')
    setting.update(value: Time.now.to_i)
  end

  private

  def initialize_attributes
    KEYS.each do |key|
      instance_variable_set("@#{key}", Setting.public_send(key)) if instance_variable_get("@#{key}").nil?
    end
  end

  def typecast_value(key, value)
    if BOOLEAN_KEYS.include?(key)
      value == '1'
    else
      value
    end
  end
end
