# frozen_string_literal: true

require 'singleton'

class RemoteSynchronizationManager
  include Singleton
  include RoutingHelper

  PROCESSING_VALUE = '!processing'
  LOCK_TIME        = 5.minutes.seconds
  CACHE_TIME       = 1.day.seconds

  def get_processed_url(remote_url)
    redis = synchronization_redis
    return if redis.nil?

    lock_options = { redis: redis, key: "process:#{remote_url}" }

    RedisLock.acquire(lock_options) do |lock|
      if lock.acquired?
        url = redis.get("processed_media_url:#{remote_url}")
        redis.setex("processed_media_url:#{remote_url}", LOCK_TIME, PROCESSING_VALUE) if url.nil?
        url
      end
    end
  rescue Redis::BaseError => e
    Rails.logger.warn "Error during synchronization: #{e}"
    nil
  end

  def set_processed_url(remote_url, object_url)
    redis = synchronization_redis
    return if redis.nil?

    if object_url.nil?
      redis.del("processed_media_url:#{remote_url}")
    else
      redis.setex("processed_media_url:#{remote_url}", CACHE_TIME, full_asset_url(object_url))
    end
  rescue Redis::BaseError => e
    Rails.logger.warn "Error during synchronization: #{e}"

    nil
  end

  private

  def synchronization_redis
    return @synchronization_redis if defined?(@synchronization_redis)

    redis_url = Rails.configuration.x.synchronization_redis_url
    return if redis_url.blank?

    redis_connection = Redis.new(
      url: redis_url,
      driver: :hiredis
    )

    namespace = Rails.configuration.x.synchronization_redis_namespace

    @synchronization_redis = namespace ? Redis::Namespace.new(namespace, redis: redis_connection) : redis_connection
  end
end
