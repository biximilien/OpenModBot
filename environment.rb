require "dotenv"
Dotenv.load

# Environment variables. Keep constants for the current app structure, while
# centralizing validation so startup errors are clear.
OPENAI_API_KEY = ENV["OPENAI_API_KEY"]
DISCORD_BOT_TOKEN = ENV["DISCORD_BOT_TOKEN"]
REDIS_URL = ENV["REDIS_URL"]
OPENAI_MODERATION_MODEL = ENV.fetch("OPENAI_MODERATION_MODEL", "omni-moderation-latest")
OPENAI_REWRITE_MODEL = ENV.fetch("OPENAI_REWRITE_MODEL", "gpt-4.1-mini")

module Environment
  REQUIRED_VARIABLES = {
    "OPENAI_API_KEY" => OPENAI_API_KEY,
    "DISCORD_BOT_TOKEN" => DISCORD_BOT_TOKEN,
    "REDIS_URL" => REDIS_URL,
  }.freeze

  def self.validate!
    missing = REQUIRED_VARIABLES.select { |_name, value| value.nil? || value.strip.empty? }.keys
    return if missing.empty?

    raise "Missing required environment variables: #{missing.join(', ')}"
  end
end
