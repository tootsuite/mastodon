# frozen_string_literal: true
# == Schema Information
#
# Table name: users
#
#  id                        :bigint(8)        not null, primary key
#  email                     :string           default(""), not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  encrypted_password        :string           default(""), not null
#  reset_password_token      :string
#  reset_password_sent_at    :datetime
#  remember_created_at       :datetime
#  sign_in_count             :integer          default(0), not null
#  current_sign_in_at        :datetime
#  last_sign_in_at           :datetime
#  admin                     :boolean          default(FALSE), not null
#  confirmation_token        :string
#  confirmed_at              :datetime
#  confirmation_sent_at      :datetime
#  unconfirmed_email         :string
#  locale                    :string
#  encrypted_otp_secret      :string
#  encrypted_otp_secret_iv   :string
#  encrypted_otp_secret_salt :string
#  consumed_timestep         :integer
#  otp_required_for_login    :boolean          default(FALSE), not null
#  last_emailed_at           :datetime
#  otp_backup_codes          :string           is an Array
#  filtered_languages        :string           default([]), not null, is an Array
#  account_id                :bigint(8)        not null
#  disabled                  :boolean          default(FALSE), not null
#  moderator                 :boolean          default(FALSE), not null
#  invite_id                 :bigint(8)
#  remember_token            :string
#  chosen_languages          :string           is an Array
#  created_by_application_id :bigint(8)
#  approved                  :boolean          default(TRUE), not null
#  sign_in_token             :string
#  sign_in_token_sent_at     :datetime
#  webauthn_id               :string
#  sign_up_ip                :inet
#

class User < ApplicationRecord
  include Settings::Extend
  include UserRoles

  # The home and list feeds will be stored in Redis for this amount
  # of time, and status fan-out to followers will include only people
  # within this time frame. Lowering the duration may improve performance
  # if lots of people sign up, but not a lot of them check their feed
  # every day. Raising the duration reduces the amount of expensive
  # RegenerationWorker jobs that need to be run when those people come
  # to check their feed
  ACTIVE_DURATION = ENV.fetch('USER_ACTIVE_DAYS', 7).to_i.days.freeze

  devise :two_factor_authenticatable,
         otp_secret_encryption_key: Rails.configuration.x.otp_secret

  devise :two_factor_backupable,
         otp_number_of_backup_codes: 10

  devise :registerable, :recoverable, :rememberable, :validatable,
         :confirmable

  include Omniauthable
  include PamAuthenticable
  include LdapAuthenticable

  belongs_to :account, inverse_of: :user
  belongs_to :invite, counter_cache: :uses, optional: true
  belongs_to :created_by_application, class_name: 'Doorkeeper::Application', optional: true
  accepts_nested_attributes_for :account

  has_many :applications, class_name: 'Doorkeeper::Application', as: :owner
  has_many :backups, inverse_of: :user
  has_many :invites, inverse_of: :user
  has_many :markers, inverse_of: :user, dependent: :destroy
  has_many :webauthn_credentials, dependent: :destroy
  has_many :ips, class_name: 'UserIP', inverse_of: :user

  has_one :invite_request, class_name: 'UserInviteRequest', inverse_of: :user, dependent: :destroy
  accepts_nested_attributes_for :invite_request, reject_if: ->(attributes) { attributes['text'].blank? && !Setting.require_invite_text }
  validates :invite_request, presence: true, on: :create, if: :invite_text_required?

  validates :locale, inclusion: I18n.available_locales.map(&:to_s), if: :locale?
  validates_with BlacklistedEmailValidator, on: :create
  validates_with EmailMxValidator, if: :validate_email_dns?
  validates :agreement, acceptance: { allow_nil: false, accept: [true, 'true', '1'] }, on: :create

  # Those are honeypot/antispam fields
  attr_accessor :registration_form_time, :website, :confirm_password

  validates_with RegistrationFormTimeValidator, on: :create
  validates :website, absence: true, on: :create
  validates :confirm_password, absence: true, on: :create

  scope :recent, -> { order(id: :desc) }
  scope :pending, -> { where(approved: false) }
  scope :approved, -> { where(approved: true) }
  scope :confirmed, -> { where.not(confirmed_at: nil) }
  scope :enabled, -> { where(disabled: false) }
  scope :disabled, -> { where(disabled: true) }
  scope :inactive, -> { where(arel_table[:current_sign_in_at].lt(ACTIVE_DURATION.ago)) }
  scope :active, -> { confirmed.where(arel_table[:current_sign_in_at].gteq(ACTIVE_DURATION.ago)).joins(:account).where(accounts: { suspended_at: nil }) }
  scope :matches_email, ->(value) { where(arel_table[:email].matches("#{value}%")) }
  scope :matches_ip, ->(value) { left_joins(:ips).where('user_ips.ip <<= ?', value) }
  scope :emailable, -> { confirmed.enabled.joins(:account).merge(Account.searchable) }

  before_validation :sanitize_languages
  before_create :set_approved
  after_commit :send_pending_devise_notifications

  # This avoids a deprecation warning from Rails 5.1
  # It seems possible that a future release of devise-two-factor will
  # handle this itself, and this can be removed from our User class.
  attribute :otp_secret

  has_many :session_activations, dependent: :destroy

  delegate :auto_play_gif, :default_sensitive, :unfollow_modal, :boost_modal, :delete_modal,
           :reduce_motion, :system_font_ui, :noindex, :theme, :display_media, :hide_network,
           :expand_spoilers, :default_language, :aggregate_reblogs, :show_application,
           :advanced_layout, :use_blurhash, :use_pending_items, :trends, :crop_images,
           :disable_swiping,
           to: :settings, prefix: :setting, allow_nil: false

  attr_reader :invite_code, :sign_in_token_attempt
  attr_writer :external, :bypass_invite_request_check

  def confirmed?
    confirmed_at.present?
  end

  def invited?
    invite_id.present?
  end

  def valid_invitation?
    invite_id.present? && invite.valid_for_use?
  end

  def disable!
    update!(disabled: true)
  end

  def enable!
    update!(disabled: false)
  end

  def confirm
    new_user      = !confirmed?
    self.approved = true if open_registrations? && !sign_up_from_ip_requires_approval?

    super

    if new_user && approved?
      prepare_new_user!
    elsif new_user
      notify_staff_about_pending_account!
    end
  end

  def confirm!
    new_user      = !confirmed?
    self.approved = true if open_registrations?

    skip_confirmation!
    save!

    prepare_new_user! if new_user && approved?
  end

  def update_sign_in!(request, new_sign_in: false)
    old_current, new_current = current_sign_in_at, Time.now.utc
    self.last_sign_in_at     = old_current || new_current
    self.current_sign_in_at  = new_current

    if new_sign_in
      self.sign_in_count ||= 0
      self.sign_in_count  += 1
    end

    save(validate: false) unless new_record?
    prepare_returning_user!
  end

  def pending?
    !approved?
  end

  def active_for_authentication?
    !account.memorial?
  end

  def suspicious_sign_in?(ip)
    !otp_required_for_login? && !ips.where(ip: ip).exist?
  end

  def functional?
    confirmed? && approved? && !disabled? && !account.suspended? && !account.memorial? && account.moved_to_account_id.nil?
  end

  def unconfirmed_or_pending?
    !(confirmed? && approved?)
  end

  def inactive_message
    !approved? ? :pending : super
  end

  def approve!
    return if approved?

    update!(approved: true)
    prepare_new_user!
  end

  def otp_enabled?
    otp_required_for_login
  end

  def webauthn_enabled?
    webauthn_credentials.any?
  end

  def two_factor_enabled?
    otp_required_for_login? || webauthn_credentials.any?
  end

  def disable_two_factor!
    self.otp_required_for_login = false
    self.otp_secret = nil
    otp_backup_codes&.clear

    webauthn_credentials.destroy_all if webauthn_enabled?

    save!
  end

  def setting_default_privacy
    settings.default_privacy || (account.locked? ? 'private' : 'public')
  end

  def allows_digest_emails?
    settings.notification_emails['digest']
  end

  def allows_report_emails?
    settings.notification_emails['report']
  end

  def allows_pending_account_emails?
    settings.notification_emails['pending_account']
  end

  def allows_trending_tag_emails?
    settings.notification_emails['trending_tag']
  end

  def hides_network?
    @hides_network ||= settings.hide_network
  end

  def aggregates_reblogs?
    @aggregates_reblogs ||= settings.aggregate_reblogs
  end

  def shows_application?
    @shows_application ||= settings.show_application
  end

  # rubocop:disable Naming/MethodParameterName
  def token_for_app(a)
    return nil if a.nil? || a.owner != self
    Doorkeeper::AccessToken.find_or_create_by(application_id: a.id, resource_owner_id: id) do |t|
      t.scopes = a.scopes
      t.expires_in = Doorkeeper.configuration.access_token_expires_in
      t.use_refresh_token = Doorkeeper.configuration.refresh_token_enabled?
    end
  end
  # rubocop:enable Naming/MethodParameterName

  def activate_session(request)
    session_activations.activate(session_id: SecureRandom.hex,
                                 user_agent: request.user_agent,
                                 ip: request.remote_ip).session_id
  end

  def clear_other_sessions(id)
    session_activations.exclusive(id)
  end

  def session_active?(id)
    session_activations.active? id
  end

  def web_push_subscription(session)
    session.web_push_subscription.nil? ? nil : session.web_push_subscription
  end

  def invite_code=(code)
    self.invite  = Invite.find_by(code: code) if code.present?
    @invite_code = code
  end

  def password_required?
    return false if external?

    super
  end

  def external_or_valid_password?(compare_password)
    # If encrypted_password is blank, we got the user from LDAP or PAM,
    # so credentials are already valid

    encrypted_password.blank? || valid_password?(compare_password)
  end

  def send_reset_password_instructions
    return false if encrypted_password.blank?

    super
  end

  def reset_password!(new_password, new_password_confirmation)
    return false if encrypted_password.blank?

    super
  end

  def show_all_media?
    setting_display_media == 'show_all'
  end

  def hide_all_media?
    setting_display_media == 'hide_all'
  end

  def sign_in_token_expired?
    sign_in_token_sent_at.nil? || sign_in_token_sent_at < 5.minutes.ago
  end

  def generate_sign_in_token
    self.sign_in_token         = Devise.friendly_token(6)
    self.sign_in_token_sent_at = Time.now.utc
  end

  protected

  def send_devise_notification(notification, *args, **kwargs)
    # This method can be called in `after_update` and `after_commit` hooks,
    # but we must make sure the mailer is actually called *after* commit,
    # otherwise it may work on stale data. To do this, figure out if we are
    # within a transaction.

    # It seems like devise sends keyword arguments as a hash in the last
    # positional argument
    kwargs = args.pop if args.last.is_a?(Hash) && kwargs.empty?

    if ActiveRecord::Base.connection.current_transaction.try(:records)&.include?(self)
      pending_devise_notifications << [notification, args, kwargs]
    else
      render_and_send_devise_message(notification, *args, **kwargs)
    end
  end

  private

  def send_pending_devise_notifications
    pending_devise_notifications.each do |notification, args, kwargs|
      render_and_send_devise_message(notification, *args, **kwargs)
    end

    # Empty the pending notifications array because the
    # after_commit hook can be called multiple times which
    # could cause multiple emails to be sent.
    pending_devise_notifications.clear
  end

  def pending_devise_notifications
    @pending_devise_notifications ||= []
  end

  def render_and_send_devise_message(notification, *args, **kwargs)
    devise_mailer.send(notification, self, *args, **kwargs).deliver_later
  end

  def set_approved
    self.approved = begin
      if sign_up_from_ip_requires_approval?
        false
      else
        open_registrations? || valid_invitation? || external?
      end
    end
  end

  def sign_up_from_ip_requires_approval?
    !sign_up_ip.nil? && IpBlock.where(severity: :sign_up_requires_approval).where('ip >>= ?', sign_up_ip.to_s).exists?
  end

  def open_registrations?
    Setting.registrations_mode == 'open'
  end

  def external?
    !!@external
  end

  def bypass_invite_request_check?
    @bypass_invite_request_check
  end

  def sanitize_languages
    return if chosen_languages.nil?
    chosen_languages.reject!(&:blank?)
    self.chosen_languages = nil if chosen_languages.empty?
  end

  def prepare_new_user!
    BootstrapTimelineWorker.perform_async(account_id)
    ActivityTracker.increment('activity:accounts:local')
    UserMailer.welcome(self).deliver_later
  end

  def prepare_returning_user!
    ActivityTracker.record('activity:logins', id)
    regenerate_feed! if needs_feed_update?
  end

  def notify_staff_about_pending_account!
    User.staff.includes(:account).find_each do |u|
      next unless u.allows_pending_account_emails?
      AdminMailer.new_pending_account(u.account, self).deliver_later
    end
  end

  def regenerate_feed!
    RegenerationWorker.perform_async(account_id) if Redis.current.set("account:#{account_id}:regeneration", true, nx: true, ex: 1.day.seconds)
  end

  def needs_feed_update?
    last_sign_in_at < ACTIVE_DURATION.ago
  end

  def validate_email_dns?
    email_changed? && !external? && !(Rails.env.test? || Rails.env.development?)
  end

  def invite_text_required?
    Setting.require_invite_text && !invited? && !external? && !bypass_invite_request_check?
  end
end
