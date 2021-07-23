# frozen_string_literal: true

class InviteRequestValidator < ActiveModel::Validator
  def validate(invite_request)
    invite_request.errors.add(:text, I18n.t('users.invalid_invite_request_text')) if invalid_text?(invite_request)
  end

  private

  def invalid_text?(invite_request)
    filters = RegistrationFilter.all.to_a
    filters.map! do |filter|
      if filter.regexp_type?
        /#{filter.phrase}/i
      elsif filter.whole_word
        sb = /\A[[:word:]]/.match?(filter.phrase) ? '\b' : ''
        eb = /[[:word:]]\z/.match?(filter.phrase) ? '\b' : ''

        /(?mix:#{sb}#{Regexp.escape(filter.phrase)}#{eb})/
      else
        /#{Regexp.escape(filter.phrase)}/i
      end
    end

    return false if filters.empty?

    combined_regex = filters.reduce { |memo, obj| Regexp.union(memo, obj) }
    combined_regex.match?(invite_request.text)
  end
end
