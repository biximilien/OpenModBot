require_relative "backend"
require_relative "open_ai"

module ModerationGPT
  class Application
    include Backend
    include OpenAI

    def initialize
      initialize_backend
    end

    def database_connection
      @database_connection ||= begin
        database_url = Environment.database_url
        raise "DATABASE_URL is required when harassment storage uses postgres" if database_url.nil? || database_url.strip.empty?

        require "pg"
        PG.connect(database_url)
      end
    end
  end
end
