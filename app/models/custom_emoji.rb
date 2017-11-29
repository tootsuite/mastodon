# frozen_string_literal: true
# == Schema Information
#
# Table name: custom_emojis
#
#  id                 :integer          not null, primary key
#  shortcode          :string           default(""), not null
#  domain             :string
#  image_file_name    :string
#  image_content_type :string
#  image_file_size    :integer
#  image_updated_at   :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  disabled           :boolean          default(FALSE), not null
#  uri                :string
#  image_remote_url   :string
#  visible_in_picker  :boolean          default(TRUE), not null
#

class CustomEmoji < ApplicationRecord
  SHORTCODE_RE_FRAGMENT = '[a-zA-Z0-9_]{2,}'

  HTML_SCAN_RE = /(?<=>|[[:space:]]|^)
    :(#{SHORTCODE_RE_FRAGMENT}):
    (?=<|[[:space:]]|$)/x

  RAW_SCAN_RE = /(?<=[[:space:]]|^)
    :(#{SHORTCODE_RE_FRAGMENT}):
    (?=[[:space:]]|$)/x

  has_one :local_counterpart, -> { where(domain: nil) }, class_name: 'CustomEmoji', primary_key: :shortcode, foreign_key: :shortcode

  has_attached_file :image, styles: { static: { format: 'png', convert_options: '-coalesce -strip' } }

  validates_attachment :image, content_type: { content_type: 'image/png' }, presence: true, size: { in: 0..50.kilobytes }
  validates :shortcode, uniqueness: { scope: :domain }, format: { with: /\A#{SHORTCODE_RE_FRAGMENT}\z/ }, length: { minimum: 2 }

  scope :local,      -> { where(domain: nil) }
  scope :remote,     -> { where.not(domain: nil) }
  scope :alphabetic, -> { order(domain: :asc, shortcode: :asc) }

  include Remotable

  def local?
    domain.nil?
  end

  def object_type
    :emoji
  end
end
