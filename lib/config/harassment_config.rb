require_relative "env_reader"

module OpenModBot
  module Config
    class HarassmentConfig
      DEFAULT_CLASSIFIER_CACHE_TTL_SECONDS = 3_600
      DEFAULT_CLASSIFIER_RATE_LIMIT_PER_MINUTE = 30

      include EnvReader

      def initialize(ai_provider_config:, env: ENV)
        @env = env
        @ai_provider_config = ai_provider_config
      end

      def classifier_model
        configured = env("HARASSMENT_CLASSIFIER_MODEL", nil)
        return configured unless configured.nil? || configured.strip.empty?

        @ai_provider_config.classifier_model
      end

      def classifier_cache_ttl_seconds
        env("HARASSMENT_CLASSIFIER_CACHE_TTL_SECONDS", DEFAULT_CLASSIFIER_CACHE_TTL_SECONDS).to_i
      end

      def classifier_rate_limit_per_minute
        env("HARASSMENT_CLASSIFIER_RATE_LIMIT_PER_MINUTE", DEFAULT_CLASSIFIER_RATE_LIMIT_PER_MINUTE).to_i
      end
    end
  end
end
