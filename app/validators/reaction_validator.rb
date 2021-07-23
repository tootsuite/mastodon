# frozen_string_literal: true

class ReactionValidator < ActiveModel::Validator
  SUPPORTED_EMOJIS = Oj.load_file(Rails.root.join('app', 'javascript', 'mastodon', 'features', 'emoji', 'emoji_map.json').to_s).keys.freeze

  LIMIT = 8

  def validate(reaction)
    return if reaction.name.blank?

    reaction.errors.add(:name, I18n.t('reactions.errors.unrecognized_emoji')) if reaction.custom_emoji_id.blank? && !unicode_emoji?(reaction.name)
    reaction.errors.add(:base, I18n.t('reactions.errors.limit_reached')) if new_reaction?(reaction) && limit_reached?(reaction)
  end

  private

  def unicode_emoji?(name)
    SUPPORTED_EMOJIS.include?(name)
  end

  def new_reaction?(reaction)
    !reaction.announcement.announcement_reactions.where(name: reaction.name).exists?
  end

  def limit_reached?(reaction)
    reaction.announcement.announcement_reactions.where.not(name: reaction.name).count('distinct name') >= LIMIT
  end
end
