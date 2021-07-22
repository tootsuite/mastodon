# frozen_string_literal: true

# == Schema Information
#
# Table name: account_statuses_cleanup_policies
#
#  id                 :bigint           not null, primary key
#  account_id         :bigint           not null
#  enabled            :boolean          default(TRUE), not null
#  min_status_age     :integer          default(1209600), not null
#  keep_direct        :boolean          default(TRUE), not null
#  keep_pinned        :boolean          default(TRUE), not null
#  keep_polls         :boolean          default(FALSE), not null
#  keep_media         :boolean          default(FALSE), not null
#  keep_self_fav      :boolean          default(TRUE), not null
#  keep_self_bookmark :boolean          default(TRUE), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
class AccountStatusesCleanupPolicy < ApplicationRecord
  ALLOWED_MIN_STATUS_AGE = [2.weeks.seconds, 1.month.seconds, 2.months.seconds, 3.months.seconds, 6.months.seconds, 1.year.seconds, 2.years.seconds].freeze
  EARLY_SEARCH_CUTOFF    = 5000

  belongs_to :account

  validates :min_status_age, inclusion: { in: ALLOWED_MIN_STATUS_AGE }
  validate :validate_local_account

  def statuses_to_delete(limit = 50, max_id = nil)
    scope = account.statuses
    scope = scope.where(Status.arel_table[:id].lt(max_id)) if max_id.present?

    scope.merge!(old_enough_scope)
    scope.merge!(without_direct_scope) if keep_direct?
    scope.merge!(without_pinned_scope) if keep_pinned?
    scope.merge!(without_poll_scope) if keep_polls?
    scope.merge!(without_media_scope) if keep_media?
    scope.merge!(without_self_fav_scope) if keep_self_fav?
    scope.merge!(without_self_bookmark_scope) if keep_self_bookmark?

    scope.reorder(id: :asc).limit(limit)
  end

  def get_cutoff_id
    max_id = 0 # TODO
    subquery = account.statuses.select(:id).where(Status.arel_table[:id].gt(max_id)).reorder(id: :asc).limit(EARLY_SEARCH_CUTOFF).to_sql
    Status.connection.execute("SELECT MAX(id) FROM (#{subquery}) t").values.first.first
  end

  private

  def validate_local_account
    errors.add(:account, :invalid) unless account&.local?
  end

  def without_direct_scope
    Status.where.not(visibility: :direct)
  end

  def old_enough_scope
    # Filtering on `id` rather than `min_status_age` ago will treat
    # non-snowflake statuses as older than they really are, but Mastodon
    # has switched to snowflake IDs significantly over 2 years ago anyway.
    Status.where(Status.arel_table[:id].lt(Mastodon::Snowflake.id_at(min_status_age.seconds.ago)))
  end

  def without_self_fav_scope
    Status.where('NOT EXISTS (SELECT * FROM favourites fav WHERE fav.account_id = statuses.account_id AND fav.status_id = statuses.id)')
  end

  def without_self_bookmark_scope
    Status.where('NOT EXISTS (SELECT * FROM bookmarks bookmark WHERE bookmark.account_id = statuses.account_id AND bookmark.status_id = statuses.id)')
  end

  def without_pinned_scope
    Status.where('NOT EXISTS (SELECT * FROM status_pins pin WHERE pin.account_id = statuses.account_id AND pin.status_id = statuses.id)')
  end

  def without_media_scope
    Status.where('NOT EXISTS (SELECT * FROM media_attachments media WHERE media.status_id = statuses.id)')
  end

  def without_poll_scope
    Status.where(poll_id: nil)
  end
end
