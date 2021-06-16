# frozen_string_literal: true

module UserTrackingConcern
  extend ActiveSupport::Concern

  UPDATE_SIGN_IN_FREQUENCY = 24.hours.freeze

  included do
    before_action :update_user_sign_in
  end

  private

  def update_user_sign_in
    current_user.update_sign_in!(request) if user_needs_sign_in_update?
  end

  def user_needs_sign_in_update?
    user_signed_in? && (current_user.current_sign_in_at.nil? || current_user.current_sign_in_at < UPDATE_SIGN_IN_FREQUENCY.ago)
  end
end
