require_relative "../plugin"
require_relative "../../environment"
require_relative "../harassment/open_ai_classifier"
require_relative "../harassment/incident_query"
require_relative "../harassment/query_service"
require_relative "../harassment/read_model"
require_relative "../harassment/repository_factory"
require_relative "harassment_command"

module ModerationGPT
  module Plugins
    class HarassmentPlugin < Plugin
      INTENTS = %w[neutral friendly teasing aggressive abusive threatening].freeze
      TARGET_TYPES = %w[individual group self none].freeze
      TOXICITY_DIMENSIONS = %w[insult threat profanity exclusion harassment].freeze
      CLASSIFIER_VERSION = "harassment-v1".freeze
      PROMPT_VERSION = "harassment-prompt-v1".freeze
      SCORE_VERSION = "harassment-score-v1".freeze
      CLASSIFIER_SCHEMA_NAME = "harassment_classification".freeze
      CLASSIFIER_RESPONSE_SCHEMA = {
        type: "object",
        additionalProperties: false,
        required: %w[intent target_type toxicity_dimensions severity_score confidence],
        properties: {
          intent: {
            type: "string",
            enum: INTENTS,
          },
          target_type: {
            type: "string",
            enum: TARGET_TYPES,
          },
          toxicity_dimensions: {
            type: "object",
            additionalProperties: false,
            required: TOXICITY_DIMENSIONS,
            properties: TOXICITY_DIMENSIONS.to_h { |dimension| [dimension, { type: "boolean" }] },
          },
          severity_score: {
            type: "number",
            minimum: 0.0,
            maximum: 1.0,
          },
          confidence: {
            type: "number",
            minimum: 0.0,
            maximum: 1.0,
          },
        },
      }.freeze
      CLASSIFIER_INSTRUCTIONS = <<~TEXT.freeze
        Classify a Discord moderation event for harassment analysis.
        Return only structured JSON that matches the supplied schema.
        Use the message content and target metadata to infer:
        - intent
        - target_type
        - toxicity_dimensions
        - severity_score
        - confidence
        Do not recommend punishment or policy actions.
        Treat this as semantic labeling only.
      TEXT

      attr_reader :read_model

      def initialize(
        read_model: Harassment::ReadModel.new(score_version: SCORE_VERSION)
      )
        @read_model = read_model
        @query_service = Harassment::QueryService.new(read_model: @read_model)
      end

      def boot(app:, **)
        factory = Harassment::RepositoryFactory.new(
          backend: Environment.harassment_storage_backend,
          redis: app.redis,
          connection: (Environment.harassment_storage_backend == "postgres" ? app.database_connection : nil),
        )
        incident_query = Harassment::IncidentQuery.new(
          interaction_events: factory.interaction_events,
          classification_records: factory.classification_records,
        )

        read_model =
          if Environment.harassment_storage_backend == "postgres"
            Harassment::ReadModel.new(
              score_version: SCORE_VERSION,
              edge_repository: factory.relationship_edges,
            )
          else
            @read_model
          end

        configure_queries(
          read_model: read_model,
          incident_query: incident_query,
        )
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
        CLASSIFIER_VERSION
      end

      def prompt_version
        PROMPT_VERSION
      end

      def score_version
        SCORE_VERSION
      end

      def build_classifier(client:, model: Environment.harassment_classifier_model)
        Harassment::OpenAIClassifier.new(
          client: client,
          model: model,
          instructions: CLASSIFIER_INSTRUCTIONS,
          schema_name: CLASSIFIER_SCHEMA_NAME,
          response_schema: CLASSIFIER_RESPONSE_SCHEMA,
          prompt_version: prompt_version,
        )
      end

      def commands
        [HarassmentCommand.new(self)]
      end

      private

      def configure_read_model(read_model)
        @read_model = read_model
        @query_service = Harassment::QueryService.new(read_model: @read_model)
      end

      def configure_queries(read_model:, incident_query:)
        @read_model = read_model
        @query_service = Harassment::QueryService.new(
          read_model: @read_model,
          incident_query: incident_query,
        )
      end
    end
  end
end
