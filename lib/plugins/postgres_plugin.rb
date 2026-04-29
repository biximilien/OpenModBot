require_relative "../plugin"
require_relative "../../environment"

module ModerationGPT
  module Plugins
    class PostgresPlugin < Plugin
      def boot(**)
        database_connection
      end

      def database_connection
        @database_connection ||= begin
          database_url = Environment.database_url
          if database_url.nil? || database_url.strip.empty?
            raise "DATABASE_URL is required when postgres plugin is enabled"
          end

          require "pg"
          PG.connect(database_url)
        end
      end

      def capabilities
        { postgres_connection: database_connection }
      end

      alias connection database_connection
      alias postgres_connection database_connection
    end
  end
end
