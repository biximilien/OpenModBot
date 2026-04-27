require_relative "incident_query"
require_relative "query_service"
require_relative "read_model"
require_relative "repository_factory"
require_relative "../plugins/postgres_plugin"
require_relative "../../environment"

module Harassment
  class PluginBootstrap
    def initialize(
      app:,
      plugin_registry:,
      storage_backend: Environment.harassment_storage_backend,
      score_version:,
      current_read_model:
    )
      @app = app
      @plugin_registry = plugin_registry
      @storage_backend = storage_backend
      @score_version = score_version
      @current_read_model = current_read_model
    end

    def build
      factory = RepositoryFactory.new(
        backend: storage_backend,
        redis: @app.redis,
        connection: postgres_connection,
      )
      read_model = build_read_model(factory)
      incident_query = IncidentQuery.new(
        interaction_events: factory.interaction_events,
        classification_records: factory.classification_records,
      )

      {
        read_model: read_model,
        query_service: QueryService.new(read_model:, incident_query:),
      }
    end

    private

    def build_read_model(factory)
      return @current_read_model unless storage_backend == "postgres"

      ReadModel.new(
        score_version: @score_version,
        edge_repository: factory.relationship_edges,
      )
    end

    def postgres_connection
      return nil unless storage_backend == "postgres"

      postgres_plugin = @plugin_registry&.find_plugin(ModerationGPT::Plugins::PostgresPlugin)
      return postgres_plugin.database_connection if postgres_plugin

      raise "HARASSMENT_STORAGE_BACKEND=postgres requires the postgres plugin to be enabled"
    end

    def storage_backend
      @storage_backend
    end
  end
end
