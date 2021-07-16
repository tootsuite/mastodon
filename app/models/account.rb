# frozen_string_literal: true
# == Schema Information
#
# Table name: accounts
#
#  id                            :bigint(8)        not null, primary key
#  username                      :string           default(""), not null
#  domain                        :string
#  private_key                   :text
#  public_key                    :text             default(""), not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  note                          :text             default(""), not null
#  display_name                  :string           default(""), not null
#  uri                           :string           default(""), not null
#  url                           :string
#  avatar_file_name              :string
#  avatar_content_type           :string
#  avatar_file_size              :integer
#  avatar_updated_at             :datetime
#  header_file_name              :string
#  header_content_type           :string
#  header_file_size              :integer
#  header_updated_at             :datetime
#  avatar_remote_url             :string
#  locked                        :boolean          default(FALSE), not null
#  header_remote_url             :string           default(""), not null
#  last_webfingered_at           :datetime
#  inbox_url                     :string           default(""), not null
#  outbox_url                    :string           default(""), not null
#  shared_inbox_url              :string           default(""), not null
#  followers_url                 :string           default(""), not null
#  protocol                      :integer          default("ostatus"), not null
#  memorial                      :boolean          default(FALSE), not null
#  moved_to_account_id           :bigint(8)
#  featured_collection_url       :string
#  fields                        :jsonb
#  actor_type                    :string
#  discoverable                  :boolean
#  also_known_as                 :string           is an Array
#  silenced_at                   :datetime
#  suspended_at                  :datetime
#  trust_level                   :integer
#  hide_collections              :boolean
#  avatar_storage_schema_version :integer
#  header_storage_schema_version :integer
#  devices_url                   :string
#  suspension_origin             :integer
#  sensitized_at                 :datetime
#

class Account < ApplicationRecord
  self.ignored_columns = %w(
    subscription_expires_at
    secret
    remote_url
    salmon_url
    hub_url
  )

  USERNAME_RE = /[a-z0-9_]+([a-z0-9_\.-]+[a-z0-9_]+)?/i
  MENTION_RE  = /(?<=^|[^\/[:word:]])@((#{USERNAME_RE})(?:@[[:word:]\.\-]+[a-z0-9]+)?)/i

  include AccountAssociations
  include AccountAvatar
  include AccountFinderConcern
  include AccountHeader
  include AccountInteractions
  include Attachmentable
  include Paginable
  include AccountCounters
  include DomainNormalizable
  include DomainMaterializable
  include AccountMerging

  TRUST_LEVELS = {
    untrusted: 0,
    trusted: 1,
  }.freeze

  enum protocol: [:ostatus, :activitypub]
  enum suspension_origin: [:local, :remote], _prefix: true

  validates :username, presence: true
  validates_with UniqueUsernameValidator, if: -> { will_save_change_to_username? }

  # Remote user validations
  validates :username, format: { with: /\A#{USERNAME_RE}\z/i }, if: -> { !local? && will_save_change_to_username? }

  # Local user validations
  validates :username, format: { with: /\A[a-z0-9_]+\z/i }, length: { maximum: 30 }, if: -> { local? && will_save_change_to_username? && actor_type != 'Application' }
  validates_with UnreservedUsernameValidator, if: -> { local? && will_save_change_to_username? }
  validates :display_name, length: { maximum: 30 }, if: -> { local? && will_save_change_to_display_name? }
  validates :note, note_length: { maximum: 500 }, if: -> { local? && will_save_change_to_note? }
  validates :fields, length: { maximum: 4 }, if: -> { local? && will_save_change_to_fields? }

  scope :remote, -> { where.not(domain: nil) }
  scope :local, -> { where(domain: nil) }
  scope :partitioned, -> { order(Arel.sql('row_number() over (partition by domain)')) }
  scope :silenced, -> { where.not(silenced_at: nil) }
  scope :suspended, -> { where.not(suspended_at: nil) }
  scope :sensitized, -> { where.not(sensitized_at: nil) }
  scope :without_suspended, -> { where(suspended_at: nil) }
  scope :without_silenced, -> { where(silenced_at: nil) }
  scope :without_instance_actor, -> { where.not(id: -99) }
  scope :recent, -> { reorder(id: :desc) }
  scope :bots, -> { where(actor_type: %w(Application Service)) }
  scope :groups, -> { where(actor_type: 'Group') }
  scope :alphabetic, -> { order(domain: :asc, username: :asc) }
  scope :matches_username, ->(value) { where(arel_table[:username].matches("#{value}%")) }
  scope :matches_display_name, ->(value) { where(arel_table[:display_name].matches("#{value}%")) }
  scope :matches_domain, ->(value) { where(arel_table[:domain].matches("%#{value}%")) }
  scope :searchable, -> { without_suspended.where(moved_to_account_id: nil) }
  scope :discoverable, -> { searchable.without_silenced.where(discoverable: true).left_outer_joins(:account_stat) }
  scope :followable_by, ->(account) { joins(arel_table.join(Follow.arel_table, Arel::Nodes::OuterJoin).on(arel_table[:id].eq(Follow.arel_table[:target_account_id]).and(Follow.arel_table[:account_id].eq(account.id))).join_sources).where(Follow.arel_table[:id].eq(nil)).joins(arel_table.join(FollowRequest.arel_table, Arel::Nodes::OuterJoin).on(arel_table[:id].eq(FollowRequest.arel_table[:target_account_id]).and(FollowRequest.arel_table[:account_id].eq(account.id))).join_sources).where(FollowRequest.arel_table[:id].eq(nil)) }
  scope :by_recent_status, -> { order(Arel.sql('(case when account_stats.last_status_at is null then 1 else 0 end) asc, account_stats.last_status_at desc, accounts.id desc')) }
  scope :by_recent_sign_in, -> { order(Arel.sql('(case when users.current_sign_in_at is null then 1 else 0 end) asc, users.current_sign_in_at desc, accounts.id desc')) }
  scope :popular, -> { order('account_stats.followers_count desc') }
  scope :by_domain_and_subdomains, ->(domain) { where(domain: domain).or(where(arel_table[:domain].matches('%.' + domain))) }
  scope :not_excluded_by_account, ->(account) { where.not(id: account.excluded_from_timeline_account_ids) }
  scope :not_domain_blocked_by_account, ->(account) { where(arel_table[:domain].eq(nil).or(arel_table[:domain].not_in(account.excluded_from_timeline_domains))) }

  delegate :email,
           :unconfirmed_email,
           :current_sign_in_ip,
           :current_sign_in_at,
           :confirmed?,
           :approved?,
           :pending?,
           :disabled?,
           :unconfirmed_or_pending?,
           :role,
           :admin?,
           :moderator?,
           :staff?,
           :locale,
           :hides_network?,
           :shows_application?,
           to: :user,
           prefix: true,
           allow_nil: true

  delegate :chosen_languages, to: :user, prefix: false, allow_nil: true

  update_index('accounts#account', :self)

  def local?
    domain.nil?
  end

  def moved?
    moved_to_account_id.present?
  end

  def bot?
    %w(Application Service).include? actor_type
  end

  def instance_actor?
    id == -99
  end

  alias bot bot?

  def bot=(val)
    self.actor_type = ActiveModel::Type::Boolean.new.cast(val) ? 'Service' : 'Person'
  end

  def group?
    actor_type == 'Group'
  end

  alias group group?

  def acct
    local? ? username : "#{username}@#{domain}"
  end

  def pretty_acct
    local? ? username : "#{username}@#{Addressable::IDNA.to_unicode(domain)}"
  end

  def local_username_and_domain
    "#{username}@#{Rails.configuration.x.local_domain}"
  end

  def local_followers_count
    Follow.where(target_account_id: id).count
  end

  def to_webfinger_s
    "acct:#{local_username_and_domain}"
  end

  def searchable?
    !(suspended? || moved?)
  end

  def possibly_stale?
    last_webfingered_at.nil? || last_webfingered_at <= 1.day.ago
  end

  def trust_level
    self[:trust_level] || 0
  end

  def refresh!
    ResolveAccountService.new.call(acct) unless local?
  end

  def silenced?
    silenced_at.present?
  end

  def silence!(date = Time.now.utc)
    update!(silenced_at: date)
  end

  def unsilence!
    update!(silenced_at: nil)
  end

  def suspended?
    suspended_at.present? && !instance_actor?
  end

  def suspended_permanently?
    suspended? && deletion_request.nil?
  end

  def suspended_temporarily?
    suspended? && deletion_request.present?
  end

  def suspend!(date: Time.now.utc, origin: :local, block_email: true)
    transaction do
      create_deletion_request!
      update!(suspended_at: date, suspension_origin: origin)
      create_canonical_email_block! if block_email
    end
  end

  def unsuspend!
    transaction do
      deletion_request&.destroy!
      update!(suspended_at: nil, suspension_origin: nil)
      destroy_canonical_email_block!
    end
  end

  def sensitized?
    sensitized_at.present?
  end

  def sensitize!(date = Time.now.utc)
    update!(sensitized_at: date)
  end

  def unsensitize!
    update!(sensitized_at: nil)
  end

  def memorialize!
    update!(memorial: true)
  end

  def sign?
    true
  end

  def keypair
    @keypair ||= OpenSSL::PKey::RSA.new(private_key || public_key)
  end

  def tags_as_strings=(tag_names)
    hashtags_map = Tag.find_or_create_by_names(tag_names).index_by(&:name)

    # Remove hashtags that are to be deleted
    tags.each do |tag|
      if hashtags_map.key?(tag.name)
        hashtags_map.delete(tag.name)
      else
        tags.delete(tag)
      end
    end

    # Add hashtags that were so far missing
    hashtags_map.each_value do |tag|
      tags << tag
    end
  end

  def also_known_as
    self[:also_known_as] || []
  end

  def fields
    (self[:fields] || []).map { |f| Field.new(self, f) }
  end

  def fields_attributes=(attributes)
    fields     = []
    old_fields = self[:fields] || []
    old_fields = [] if old_fields.is_a?(Hash)

    if attributes.is_a?(Hash)
      attributes.each_value do |attr|
        next if attr[:name].blank?

        previous = old_fields.find { |item| item['value'] == attr[:value] }

        if previous && previous['verified_at'].present?
          attr[:verified_at] = previous['verified_at']
        end

        fields << attr
      end
    end

    self[:fields] = fields
  end

  DEFAULT_FIELDS_SIZE = 4

  def build_fields
    return if fields.size >= DEFAULT_FIELDS_SIZE

    tmp = self[:fields] || []
    tmp = [] if tmp.is_a?(Hash)

    (DEFAULT_FIELDS_SIZE - tmp.size).times do
      tmp << { name: '', value: '' }
    end

    self.fields = tmp
  end

  def save_with_optional_media!
    save!
  rescue ActiveRecord::RecordInvalid
    self.avatar = nil
    self.header = nil

    save!
  end

  def hides_followers?
    hide_collections? || user_hides_network?
  end

  def hides_following?
    hide_collections? || user_hides_network?
  end

  def object_type
    :person
  end

  def to_param
    username
  end

  def excluded_from_timeline_account_ids
    Rails.cache.fetch("exclude_account_ids_for:#{id}") { block_relationships.pluck(:target_account_id) + blocked_by_relationships.pluck(:account_id) + mute_relationships.pluck(:target_account_id) }
  end

  def excluded_from_timeline_domains
    Rails.cache.fetch("exclude_domains_for:#{id}") { domain_blocks.pluck(:domain) }
  end

  def preferred_inbox_url
    shared_inbox_url.presence || inbox_url
  end

  def synchronization_uri_prefix
    return 'local' if local?

    @synchronization_uri_prefix ||= "#{uri[/\Ahttp(s?):\/\/[^\/]+/]}/"
  end

  class Field < ActiveModelSerializers::Model
    attributes :name, :value, :verified_at, :account

    def initialize(account, attributes)
      @original_field = attributes
      string_limit = account.local? ? 255 : 2047
      super(
        account:     account,
        name:        attributes['name'].strip[0, string_limit],
        value:       attributes['value'].strip[0, string_limit],
        verified_at: attributes['verified_at']&.to_datetime,
      )
    end

    def verified?
      verified_at.present?
    end

    def value_for_verification
      @value_for_verification ||= begin
        if account.local?
          value
        else
          ActionController::Base.helpers.strip_tags(value)
        end
      end
    end

    def verifiable?
      value_for_verification.present? && value_for_verification.start_with?('http://', 'https://')
    end

    def mark_verified!
      self.verified_at = Time.now.utc
      @original_field['verified_at'] = verified_at
    end

    def to_h
      { name: name, value: value, verified_at: verified_at }
    end
  end

  class << self
    def readonly_attributes
      super - %w(statuses_count following_count followers_count)
    end

    def inboxes
      urls = reorder(nil).where(protocol: :activitypub).group(:preferred_inbox_url).pluck(Arel.sql("coalesce(nullif(accounts.shared_inbox_url, ''), accounts.inbox_url) AS preferred_inbox_url"))
      DeliveryFailureTracker.without_unavailable(urls)
    end

    def search_for(terms, limit = 10, offset = 0)
      textsearch, query = generate_query_for_search(terms)

      sql = <<-SQL.squish
        SELECT
          accounts.*,
          ts_rank_cd(#{textsearch}, #{query}, 32) AS rank
        FROM accounts
        WHERE #{query} @@ #{textsearch}
          AND accounts.suspended_at IS NULL
          AND accounts.moved_to_account_id IS NULL
        ORDER BY rank DESC
        LIMIT ? OFFSET ?
      SQL

      records = find_by_sql([sql, limit, offset])
      ActiveRecord::Associations::Preloader.new.preload(records, :account_stat)
      records
    end

    def advanced_search_for(terms, account, limit = 10, following = false, offset = 0)
      textsearch, query = generate_query_for_search(terms)

      if following
        sql = <<-SQL.squish
          WITH first_degree AS (
            SELECT target_account_id
            FROM follows
            WHERE account_id = ?
            UNION ALL
            SELECT ?
          )
          SELECT
            accounts.*,
            (count(f.id) + 1) * ts_rank_cd(#{textsearch}, #{query}, 32) AS rank
          FROM accounts
          LEFT OUTER JOIN follows AS f ON (accounts.id = f.account_id AND f.target_account_id = ?)
          WHERE accounts.id IN (SELECT * FROM first_degree)
            AND #{query} @@ #{textsearch}
            AND accounts.suspended_at IS NULL
            AND accounts.moved_to_account_id IS NULL
          GROUP BY accounts.id
          ORDER BY rank DESC
          LIMIT ? OFFSET ?
        SQL

        records = find_by_sql([sql, account.id, account.id, account.id, limit, offset])
      else
        sql = <<-SQL.squish
          SELECT
            accounts.*,
            (count(f.id) + 1) * ts_rank_cd(#{textsearch}, #{query}, 32) AS rank
          FROM accounts
          LEFT OUTER JOIN follows AS f ON (accounts.id = f.account_id AND f.target_account_id = ?) OR (accounts.id = f.target_account_id AND f.account_id = ?)
          WHERE #{query} @@ #{textsearch}
            AND accounts.suspended_at IS NULL
            AND accounts.moved_to_account_id IS NULL
          GROUP BY accounts.id
          ORDER BY rank DESC
          LIMIT ? OFFSET ?
        SQL

        records = find_by_sql([sql, account.id, account.id, limit, offset])
      end

      ActiveRecord::Associations::Preloader.new.preload(records, :account_stat)
      records
    end

    def from_text(text)
      return [] if text.blank?

      text.scan(MENTION_RE).map { |match| match.first.split('@', 2) }.uniq.filter_map do |(username, domain)|
        domain = begin
          if TagManager.instance.local_domain?(domain)
            nil
          else
            TagManager.instance.normalize_domain(domain)
          end
        end
        EntityCache.instance.mention(username, domain)
      end
    end

    private

    def generate_query_for_search(terms)
      terms      = Arel.sql(connection.quote(terms.gsub(/['?\\:]/, ' ')))
      textsearch = "(setweight(to_tsvector('simple', accounts.display_name), 'A') || setweight(to_tsvector('simple', accounts.username), 'B') || setweight(to_tsvector('simple', coalesce(accounts.domain, '')), 'C'))"
      query      = "to_tsquery('simple', ''' ' || #{terms} || ' ''' || ':*')"

      [textsearch, query]
    end
  end

  def emojis
    @emojis ||= CustomEmoji.from_text(emojifiable_text, domain)
  end

  before_create :generate_keys
  before_validation :prepare_contents, if: :local?
  before_validation :prepare_username, on: :create
  before_destroy :clean_feed_manager

  private

  def prepare_contents
    display_name&.strip!
    note&.strip!
  end

  def prepare_username
    username&.squish!
  end

  def generate_keys
    return unless local? && private_key.blank? && public_key.blank?

    keypair = OpenSSL::PKey::RSA.new(2048)
    self.private_key = keypair.to_pem
    self.public_key  = keypair.public_key.to_pem
  end

  def normalize_domain
    return if local?

    super
  end

  def emojifiable_text
    [note, display_name, fields.map(&:name), fields.map(&:value)].join(' ')
  end

  def clean_feed_manager
    FeedManager.instance.clean_feeds!(:home, [id])
  end

  def create_canonical_email_block!
    return unless local? && user_email.present?

    begin
      CanonicalEmailBlock.create(reference_account: self, email: user_email)
    rescue ActiveRecord::RecordNotUnique
      # A canonical e-mail block may already exist for the same e-mail
    end
  end

  def destroy_canonical_email_block!
    return unless local?

    CanonicalEmailBlock.where(reference_account: self).delete_all
  end
end
