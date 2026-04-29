require_relative "../../environment"
require_relative "../moderation/stores/redis_store"
require_relative "../plugin"

module ModerationGPT
  module Plugins
    class RedisPlugin < Plugin
      def boot(app:, **)
        app.moderation_store = moderation_store
      end

      def redis
        @redis ||= begin
          raise "REDIS_URL is required when redis plugin is enabled" if missing_redis_url?

          require "redis"
          client = Redis.new(url: Environment.redis_url)
          raise "Redis connection failed" unless client.ping == "PONG"

          client
        end
      end

      def moderation_store
        @moderation_store ||= Moderation::Stores::RedisStore.new(redis:)
      end

      def capabilities
        {
          redis_client: redis,
          moderation_store: moderation_store
        }
      end

      private

      def missing_redis_url?
        Environment.redis_url.nil? || Environment.redis_url.strip.empty?
      end
    end
  end
end
