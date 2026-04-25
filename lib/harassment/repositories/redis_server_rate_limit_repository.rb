require "json"
require "time"
require_relative "../../data_model/keys"
require_relative "server_rate_limit_repository"

module Harassment
  module Repositories
    class RedisServerRateLimitRepository < ServerRateLimitRepository
      def initialize(redis:, key: DataModel::Keys.harassment_server_rate_limits)
        @redis = redis
        @key = key
      end

      def fetch(server_id)
        payload = @redis.hget(@key, server_id.to_s)
        return [] unless payload

        JSON.parse(payload).map { |timestamp| Time.parse(timestamp).utc }
      end

      def save(server_id, timestamps)
        serialized = timestamps.map { |timestamp| timestamp.utc.iso8601 }
        @redis.hset(@key, server_id.to_s, JSON.generate(serialized))
      end
    end
  end
end
