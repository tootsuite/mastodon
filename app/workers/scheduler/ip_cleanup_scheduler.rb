# frozen_string_literal: true

class Scheduler::IpCleanupScheduler
  include Sidekiq::Worker

  IP_RETENTION_PERIOD = 1.year.freeze

  sidekiq_options retry: 0

  def perform
    clean_ip_columns!
    clean_expired_ip_blocks!
  end

  private

  def clean_ip_columns!
    SessionActivation.where('updated_at < ?', IP_RETENTION_PERIOD.ago).in_batches.destroy_all
    User.where('current_sign_in_at < ?', IP_RETENTION_PERIOD.ago).in_batches.update_all(sign_up_ip: nil)
    LoginActivity.where('created_at < ?', IP_RETENTION_PERIOD.ago).in_batches.destroy_all
  end

  def clean_expired_ip_blocks!
    IpBlock.expired.in_batches.destroy_all
  end
end
