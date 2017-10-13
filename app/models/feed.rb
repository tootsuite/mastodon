# frozen_string_literal: true

class Feed
  def initialize(type, account)
    @type    = type
    @account = account
  end

  def get(limit, max_id = nil, since_id = nil)
    if redis.exists("account:#{@account.id}:regeneration")
      from_database(limit, max_id, since_id)
    else
      statuses = from_redis(limit, max_id, since_id)

      statuses += from_database(limit - statuses.size,
                                statuses.last&.id || max_id,
                                since_id)

      statuses
    end
  end

  private

  def from_redis(limit, max_id, since_id)
    max_id     = '+inf' if max_id.blank?
    since_id   = '-inf' if since_id.blank?
    unhydrated = redis.zrevrangebyscore(key, "(#{max_id}", "(#{since_id}", limit: [0, limit], with_scores: true).map(&:first).map(&:to_i)
    Status.where(id: unhydrated).cache_ids
  end

  def from_database(limit, max_id, since_id)
    Status.as_home_timeline(@account)
          .paginate_by_max_id(limit, max_id, since_id)
          .reject { |status| FeedManager.instance.filter?(:home, status, @account.id) }
  end

  def key
    FeedManager.instance.key(@type, @account.id)
  end

  def redis
    Redis.current
  end
end
