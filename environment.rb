require "dotenv"
require_relative "lib/ai/provider_config"
Dotenv.load

module Environment
  REQUIRED_VARIABLES = %w[
    DISCORD_BOT_TOKEN
  ].freeze
  DEFAULT_OPENAI_MODERATION_MODEL = "omni-moderation-latest".freeze
  DEFAULT_OPENAI_REWRITE_MODEL = "gpt-4.1-mini".freeze
  DEFAULT_GOOGLE_AI_MODEL = "gemini-2.5-flash".freeze
  DEFAULT_KARMA_AUTOMOD_THRESHOLD = -5
  DEFAULT_TELEMETRY_HASH_SALT = "development-telemetry-salt".freeze
  DEFAULT_KARMA_AUTOMOD_ACTION = "timeout".freeze
  DEFAULT_KARMA_TIMEOUT_SECONDS = 3_600
  DEFAULT_PERSONALITY = "objective".freeze
  DEFAULT_LOG_FORMAT = "json".freeze
  DEFAULT_HARASSMENT_CLASSIFIER_CACHE_TTL_SECONDS = 3_600
  DEFAULT_HARASSMENT_CLASSIFIER_RATE_LIMIT_PER_MINUTE = 30

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
    ENV.fetch("KARMA_AUTOMOD_THRESHOLD", DEFAULT_KARMA_AUTOMOD_THRESHOLD).to_i
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
    ENV.fetch("KARMA_AUTOMOD_ACTION", DEFAULT_KARMA_AUTOMOD_ACTION)
  end

  def self.karma_timeout_seconds
    ENV.fetch("KARMA_TIMEOUT_SECONDS", DEFAULT_KARMA_TIMEOUT_SECONDS).to_i
  end

  def self.log_invite_url?
    ENV.fetch("LOG_INVITE_URL", "false").casecmp("true").zero?
  end

  def self.log_format
    candidate = ENV.fetch("LOG_FORMAT", DEFAULT_LOG_FORMAT).downcase
    %w[json plain].include?(candidate) ? candidate : DEFAULT_LOG_FORMAT
  end

  def self.moderation_shadow_mode?
    ENV.fetch("MODERATION_SHADOW_MODE", "false").casecmp("true").zero?
  end

  def self.moderation_shadow_rewrite?
    ENV.fetch("MODERATION_SHADOW_REWRITE", "true").casecmp("true").zero?
  end

  def self.moderation_review_store_content?
    ENV.fetch("MODERATION_REVIEW_STORE_CONTENT", "false").casecmp("true").zero?
  end

  def self.harassment_classifier_model
    return ENV["HARASSMENT_CLASSIFIER_MODEL"] unless missing?(ENV["HARASSMENT_CLASSIFIER_MODEL"])

    ai_provider_config.classifier_model
  end

  def self.harassment_classifier_cache_ttl_seconds
    ENV.fetch("HARASSMENT_CLASSIFIER_CACHE_TTL_SECONDS", DEFAULT_HARASSMENT_CLASSIFIER_CACHE_TTL_SECONDS).to_i
  end

  def self.harassment_classifier_rate_limit_per_minute
    ENV.fetch("HARASSMENT_CLASSIFIER_RATE_LIMIT_PER_MINUTE", DEFAULT_HARASSMENT_CLASSIFIER_RATE_LIMIT_PER_MINUTE).to_i
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

  private_class_method :missing?, :ai_api_key_variable, :ai_provider_config
end
