require "dotenv"
require_relative "lib/ai/provider_config"
require_relative "lib/config/admin_notification_config"
require_relative "lib/config/harassment_config"
require_relative "lib/config/moderation_config"
Dotenv.load

module Environment
  REQUIRED_VARIABLES = %w[
    DISCORD_BOT_TOKEN
  ].freeze
  DEFAULT_OPENAI_MODERATION_MODEL = "omni-moderation-latest".freeze
  DEFAULT_OPENAI_REWRITE_MODEL = "gpt-4.1-mini".freeze
  DEFAULT_GOOGLE_AI_MODEL = "gemini-2.5-flash".freeze
  DEFAULT_TELEMETRY_HASH_SALT = "development-telemetry-salt".freeze
  DEFAULT_PERSONALITY = "objective".freeze
  DEFAULT_LOG_FORMAT = "json".freeze

  def self.validate!
    required = REQUIRED_VARIABLES + [ai_api_key_variable]
    missing = required.select { |name| missing?(ENV.fetch(name, nil)) }
    return if missing.empty?

    raise "Missing required environment variables: #{missing.join(", ")}"
  end

  def self.openai_api_key
    ENV.fetch("OPENAI_API_KEY", nil)
  end

  def self.discord_bot_token
    ENV.fetch("DISCORD_BOT_TOKEN", nil)
  end

  def self.redis_url
    ENV.fetch("REDIS_URL", nil)
  end

  def self.database_url
    ENV.fetch("DATABASE_URL", nil)
  end

  def self.openai_moderation_model
    ENV.fetch("OPENAI_MODERATION_MODEL", DEFAULT_OPENAI_MODERATION_MODEL)
  end

  def self.openai_rewrite_model
    ENV.fetch("OPENAI_REWRITE_MODEL", DEFAULT_OPENAI_REWRITE_MODEL)
  end

  def self.google_ai_api_key
    ENV.fetch("GOOGLE_AI_API_KEY", nil)
  end

  def self.google_ai_model
    ENV.fetch("GOOGLE_AI_MODEL", DEFAULT_GOOGLE_AI_MODEL)
  end

  def self.karma_automod_threshold
    moderation_config.karma_automod_threshold
  end

  def self.telemetry_hash_salt
    ENV.fetch("TELEMETRY_HASH_SALT", DEFAULT_TELEMETRY_HASH_SALT)
  end

  def self.telemetry_enabled?
    ENV.fetch("TELEMETRY_ENABLED", "false").casecmp("true").zero?
  end

  def self.enabled_plugins
    ENV.fetch("PLUGINS", "").split(",").map(&:strip).reject(&:empty?).uniq
  end

  def self.plugin_requires
    ENV.fetch("PLUGIN_REQUIRES", "").split(",").map(&:strip).reject(&:empty?)
  end

  def self.personality
    ENV.fetch("PERSONALITY", DEFAULT_PERSONALITY).downcase
  end

  def self.karma_automod_action
    moderation_config.karma_automod_action
  end

  def self.karma_timeout_seconds
    moderation_config.karma_timeout_seconds
  end

  def self.log_invite_url?
    ENV.fetch("LOG_INVITE_URL", "false").casecmp("true").zero?
  end

  def self.log_format
    candidate = ENV.fetch("LOG_FORMAT", DEFAULT_LOG_FORMAT).downcase
    %w[json plain].include?(candidate) ? candidate : DEFAULT_LOG_FORMAT
  end

  def self.moderation_shadow_mode?
    moderation_config.shadow_mode?
  end

  def self.moderation_shadow_rewrite?
    moderation_config.shadow_rewrite?
  end

  def self.moderation_review_store_content?
    moderation_config.review_store_content?
  end

  def self.harassment_classifier_model
    harassment_config.classifier_model
  end

  def self.harassment_classifier_cache_ttl_seconds
    harassment_config.classifier_cache_ttl_seconds
  end

  def self.harassment_classifier_rate_limit_per_minute
    harassment_config.classifier_rate_limit_per_minute
  end

  def self.admin_notification_channel_id = admin_notification_config.channel_id

  def self.admin_notification_ambiguous_min_score
    admin_notification_config.ambiguous_min_score
  end

  def self.admin_notification_ambiguous_max_score
    admin_notification_config.ambiguous_max_score
  end

  def self.admin_notification_shadow_mode? = admin_notification_config.shadow_mode?

  def self.admin_notification_rate_limit_per_minute
    admin_notification_config.rate_limit_per_minute
  end

  def self.missing?(value)
    value.nil? || value.strip.empty?
  end

  def self.ai_api_key_variable
    ai_provider_config.api_key_variable
  end

  def self.ai_provider_config
    OpenModBot::AI::ProviderConfig.new(enabled_plugins:)
  end

  def self.admin_notification_config
    OpenModBot::Config::AdminNotificationConfig.new
  end

  def self.harassment_config
    OpenModBot::Config::HarassmentConfig.new(ai_provider_config:)
  end

  def self.moderation_config
    OpenModBot::Config::ModerationConfig.new
  end

  private_class_method :missing?, :ai_api_key_variable, :ai_provider_config,
                       :admin_notification_config, :harassment_config, :moderation_config
end
