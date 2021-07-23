# frozen_string_literal: true
# == Schema Information
#
# Table name: registration_filters
#
#  id         :bigint(8)        not null, primary key
#  phrase     :text             default(""), not null
#  type       :integer          default(0), not null
#  whole_word :boolean          default(TRUE), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class RegistrationFilter < ApplicationRecord
  self.inheritance_column = nil

  enum type: { text: 0, regexp: 1 }, _suffix: :type

  validates :phrase, presence: true
  validates :phrase, regex: true, if: :regexp_type?
end
