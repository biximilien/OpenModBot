require_relative "../plugin"
require_relative "../harassment/classification_service"
require_relative "../harassment/plugin_bootstrap"
require_relative "../harassment/query_service"
require_relative "../harassment/score_definition"
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
          score_version: Harassment::ScoreDefinition::VERSION,
          current_read_model: @classification_service.read_model,
        ).build
        configure_runtime(**configured)
      end

      def commands
        [HarassmentCommand.new(@query_service)]
      end

      private

      def configure_runtime(read_model:, query_service:)
        @classification_service.read_model = read_model
        @query_service = query_service
      end
    end
  end
end
