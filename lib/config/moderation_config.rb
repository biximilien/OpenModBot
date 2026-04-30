require_relative "env_reader"

module OpenModBot
  module Config
    class ModerationConfig
      DEFAULT_KARMA_AUTOMOD_THRESHOLD = -5
      DEFAULT_KARMA_AUTOMOD_ACTION = "timeout".freeze
      DEFAULT_KARMA_TIMEOUT_SECONDS = 3_600

      include EnvReader

      def initialize(env: ENV)
        @env = env
      end

      def karma_automod_threshold
        env("KARMA_AUTOMOD_THRESHOLD", DEFAULT_KARMA_AUTOMOD_THRESHOLD).to_i
      end

      def karma_automod_action
        env("KARMA_AUTOMOD_ACTION", DEFAULT_KARMA_AUTOMOD_ACTION)
      end

      def karma_timeout_seconds
        env("KARMA_TIMEOUT_SECONDS", DEFAULT_KARMA_TIMEOUT_SECONDS).to_i
      end

      def shadow_mode?
        true?("MODERATION_SHADOW_MODE", default: "false")
      end

      def shadow_rewrite?
        true?("MODERATION_SHADOW_REWRITE", default: "true")
      end

      def review_store_content?
        true?("MODERATION_REVIEW_STORE_CONTENT", default: "false")
      end
    end
  end
end
