# frozen_string_literal: true

Rails.application.configure do
  config.x.synchronization_redis_url       = ENV['SYNCHRO_REDIS_URL']
  config.x.synchronization_redis_namespace = ENV['SYNCHRO_REDIS_NAMESPACE']
end
