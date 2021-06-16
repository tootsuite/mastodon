# frozen_string_literal: true

class REST::Admin::IPSerializer < ActiveModel::Serializer
  attributes :ip, :used_at
end
