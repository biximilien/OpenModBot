$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

ENV["OPENAI_API_KEY"] ||= "test-openai-key"
ENV["DISCORD_BOT_TOKEN"] ||= "test-discord-token"
ENV["REDIS_URL"] ||= "redis://localhost:6379/15"

require_relative "../environment"
require_relative "../lib/logging"
require_relative "support/discord_fixtures"

$logger = Logging.build_logger(STDOUT, level: Logger::WARN)

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end
