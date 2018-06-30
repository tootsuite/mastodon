# frozen_string_literal: true

class PotentialFriendshipTracker
  EXPIRE_AFTER = 90.days.seconds

  WEIGHTS = {
    reply: 1,
    favourite: 10,
    reblog: 20,
  }.freeze

  class << self
    def record(account_id, target_account_id, action)
      key    = "interactions:#{account_id}"
      weight = WEIGHTS[action]

      redis.zincrby(key, weight, target_account_id)
      redis.expire(key, EXPIRE_AFTER)
    end

    def remove(account_id, target_account_id)
      redis.zrem("interactions:#{account_id}", target_account_id)
    end

    def get(account_id, limit: 20, offset: 0)
      account_ids = redis.zrevrange("interactions:#{account_id}", offset, limit)
      return [] if account_ids.empty?
      Account.searchable.where(id: account_ids)
    end

    private

    def redis
      Redis.current
    end
  end
end
