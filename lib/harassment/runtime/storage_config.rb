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

      registry_postgres_connection || raise_missing_postgres_plugin
    end

    private

    def registry_postgres_connection
      return nil unless @plugin_registry
      return @plugin_registry.capability(:postgres_connection) if @plugin_registry.respond_to?(:capability)

      @plugin_registry.postgres_connection if @plugin_registry.respond_to?(:postgres_connection)
    end

    def raise_missing_postgres_plugin
      raise "HARASSMENT_STORAGE_BACKEND=postgres requires the postgres plugin to be enabled"
    end
  end
end
