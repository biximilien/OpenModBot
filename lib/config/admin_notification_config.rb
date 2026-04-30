require_relative "env_reader"

module OpenModBot
  module Config
    class AdminNotificationConfig
      DEFAULT_AMBIGUOUS_MIN_SCORE = 0.35
      DEFAULT_AMBIGUOUS_MAX_SCORE = 0.75
      DEFAULT_RATE_LIMIT_PER_MINUTE = 10

      include EnvReader

      def initialize(env: ENV)
        @env = env
      end

      def channel_id = env("ADMIN_NOTIFICATION_CHANNEL_ID", nil)

      def ambiguous_min_score
        env("ADMIN_NOTIFICATION_AMBIGUOUS_MIN_SCORE", DEFAULT_AMBIGUOUS_MIN_SCORE).to_f
      end

      def ambiguous_max_score
        env("ADMIN_NOTIFICATION_AMBIGUOUS_MAX_SCORE", DEFAULT_AMBIGUOUS_MAX_SCORE).to_f
      end

      def shadow_mode?
        true?("ADMIN_NOTIFICATION_SHADOW_MODE", default: "true")
      end

      def rate_limit_per_minute
        env("ADMIN_NOTIFICATION_RATE_LIMIT_PER_MINUTE", DEFAULT_RATE_LIMIT_PER_MINUTE).to_i
      end
    end
  end
end
