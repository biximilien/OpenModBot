require_relative "../../plugins/postgres_plugin"
require_relative "../../../environment"

module Harassment
  class StorageConfig
    def initialize(plugin_registry:, storage_backend: Environment.harassment_storage_backend)
      @plugin_registry = plugin_registry
      @storage_backend = storage_backend
    end

    attr_reader :storage_backend

    def postgres?
      storage_backend == "postgres"
    end

    def database_connection
      return nil unless postgres?

      postgres_plugin&.database_connection || raise_missing_postgres_plugin
    end

    private

    def postgres_plugin
      @plugin_registry&.find_plugin(ModerationGPT::Plugins::PostgresPlugin)
    end

    def raise_missing_postgres_plugin
      raise "HARASSMENT_STORAGE_BACKEND=postgres requires the postgres plugin to be enabled"
    end
  end
end
