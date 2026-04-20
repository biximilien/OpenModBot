require "dotenv"
Dotenv.load

module Environment
  REQUIRED_VARIABLES = %w[
    OPENAI_API_KEY
    DISCORD_BOT_TOKEN
    REDIS_URL
  ].freeze

  DEFAULT_OPENAI_MODERATION_MODEL = "omni-moderation-latest"
  DEFAULT_OPENAI_REWRITE_MODEL = "gpt-4.1-mini"
  DEFAULT_KARMA_AUTOMOD_THRESHOLD = -5
  DEFAULT_TELEMETRY_HASH_SALT = "development-telemetry-salt"
  DEFAULT_KARMA_AUTOMOD_ACTION = "timeout"
  DEFAULT_KARMA_TIMEOUT_SECONDS = 3_600

  def self.validate!
    missing = REQUIRED_VARIABLES.select { |name| missing?(ENV[name]) }
    return if missing.empty?

    raise "Missing required environment variables: #{missing.join(', ')}"
  end

  def self.openai_api_key
    ENV["OPENAI_API_KEY"]
  end

  def self.discord_bot_token
    ENV["DISCORD_BOT_TOKEN"]
  end

  def self.redis_url
    ENV["REDIS_URL"]
  end

  def self.openai_moderation_model
    ENV.fetch("OPENAI_MODERATION_MODEL", DEFAULT_OPENAI_MODERATION_MODEL)
  end

  def self.openai_rewrite_model
    ENV.fetch("OPENAI_REWRITE_MODEL", DEFAULT_OPENAI_REWRITE_MODEL)
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
    plugins = ENV.fetch("PLUGINS", "").split(",").map(&:strip).reject(&:empty?)
    plugins << "telemetry" if telemetry_enabled?
    plugins.uniq
  end

  def self.plugin_requires
    ENV.fetch("PLUGIN_REQUIRES", "").split(",").map(&:strip).reject(&:empty?)
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

  def self.missing?(value)
    value.nil? || value.strip.empty?
  end

  private_class_method :missing?
end
