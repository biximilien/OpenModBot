require_relative "../plugin"
require_relative "../harassment/classification/service"
require_relative "../harassment/runtime/runtime"
require_relative "../harassment/runtime/plugin_bootstrap"
require_relative "../harassment/runtime/storage_config"
require_relative "../harassment/runtime/worker_runner"
require_relative "../harassment/query_service"
require_relative "../harassment/risk/score_definition"
require_relative "../logging"
require_relative "harassment_command"

module ModerationGPT
  module Plugins
    class HarassmentPlugin < Plugin
      attr_reader :classification_service, :query_service

      def initialize(
        classification_service: Harassment::ClassificationService.new
      )
        @classification_service = classification_service
        @query_service = Harassment::QueryService.new(read_model: @classification_service.read_model)
      end

      def boot(app:, plugin_registry: nil, **)
        configured = Harassment::PluginBootstrap.new(
          app: app,
          plugin_registry: plugin_registry,
          storage_backend: "postgres",
          score_version: Harassment::ScoreDefinition::VERSION,
          current_read_model: @classification_service.read_model
        ).build
        configure_runtime(**configured)
        build_runtime(app:, plugin_registry:)
      end

      def ready(**)
        @worker_runner&.start
      end

      def shutdown(**)
        @worker_runner&.stop
      end

      def message(event:, **)
        interaction_event = @runtime&.ingest_message(event)
        return unless interaction_event

        Logging.info("harassment_interaction_enqueued", message_id: interaction_event.message_id,
                                                        target_count: interaction_event.target_user_ids.length)
      end

      def commands
        [HarassmentCommand.new(@query_service)]
      end

      private

      def configure_runtime(read_model:, query_service:)
        @classification_service.read_model = read_model
        @query_service = query_service
      end

      def build_runtime(app:, plugin_registry:)
        storage_config = Harassment::StorageConfig.new(plugin_registry:)
        @runtime = Harassment::Runtime.new(
          redis: nil,
          connection: storage_config.database_connection,
          storage_backend: storage_config.storage_backend,
          classifier_version: @classification_service.classifier_version,
          classifier: @classification_service.build_classifier(client: app),
          on_classification: ->(event:, record:) { @classification_service.record(event:, record:) }
        )
        @worker_runner = Harassment::WorkerRunner.new(runtime: @runtime)
      end
    end
  end
end
