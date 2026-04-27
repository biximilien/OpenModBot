require_relative "../plugin"
require_relative "../../environment"
require_relative "../harassment/classifier_definition"
require_relative "../harassment/plugin_bootstrap"
require_relative "../harassment/query_service"
require_relative "../harassment/read_model"
require_relative "harassment_command"

module ModerationGPT
  module Plugins
    class HarassmentPlugin < Plugin
      SCORE_VERSION = "harassment-score-v1".freeze

      attr_reader :read_model

      def initialize(
        read_model: Harassment::ReadModel.new(score_version: SCORE_VERSION),
        classifier_definition: Harassment::ClassifierDefinition.new
      )
        @read_model = read_model
        @classifier_definition = classifier_definition
        @query_service = Harassment::QueryService.new(read_model: @read_model)
      end

      def boot(app:, plugin_registry: nil, **)
        configured = Harassment::PluginBootstrap.new(
          app: app,
          plugin_registry: plugin_registry,
          score_version: score_version,
          current_read_model: @read_model,
        ).build
        configure_queries(**configured)
      end

      def record_classification(event:, record:)
        @read_model.ingest(event:, record:)
      end

      def get_user_risk(server_id, user_id, as_of: Time.now.utc)
        @query_service.get_user_risk(server_id, user_id, as_of:)
      end

      def get_pair_relationship(server_id, user_a, user_b, as_of: Time.now.utc)
        @query_service.get_pair_relationship(server_id, user_a, user_b, as_of:)
      end

      def recent_incidents(server_id, channel_id, limit: 10, user_id: nil, since: nil)
        @query_service.recent_incidents(server_id, channel_id, limit:, user_id:, since:)
      end

      def classifier_version
        @classifier_definition.classifier_version
      end

      def prompt_version
        @classifier_definition.prompt_version
      end

      def score_version
        SCORE_VERSION
      end

      def build_classifier(client:, model: Environment.harassment_classifier_model)
        @classifier_definition.build(client:, model:)
      end

      def commands
        [HarassmentCommand.new(self)]
      end

      private

      def configure_queries(read_model:, query_service:)
        @read_model = read_model
        @query_service = query_service
      end
    end
  end
end
