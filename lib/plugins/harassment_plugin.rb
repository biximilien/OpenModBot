require_relative "../plugin"
require_relative "../harassment/classification_pipeline"
require_relative "../harassment/classifier_version"
require_relative "../harassment/message_ingestor"
require_relative "../harassment/query_service"
require_relative "../harassment/repositories/in_memory_classification_job_repository"
require_relative "../harassment/repositories/in_memory_classification_record_repository"
require_relative "../harassment/repositories/in_memory_interaction_event_repository"
require_relative "../harassment/read_model"
require_relative "../logging"
require_relative "../../environment"

module ModerationGPT
  module Plugins
    class HarassmentPlugin < Plugin
      attr_reader :classification_jobs, :classification_pipeline, :classification_records, :interaction_events, :read_model

      DEFAULT_CLASSIFIER_VERSION = "harassment-v1".freeze

      def initialize(
        read_model: Harassment::ReadModel.new,
        interaction_events: Harassment::Repositories::InMemoryInteractionEventRepository.new,
        classification_records: Harassment::Repositories::InMemoryClassificationRecordRepository.new,
        classification_jobs: Harassment::Repositories::InMemoryClassificationJobRepository.new,
        classifier_version: DEFAULT_CLASSIFIER_VERSION
      )
        @read_model = read_model
        @classifier_version = Harassment::ClassifierVersion.build(classifier_version)
        @interaction_events = interaction_events
        @classification_records = classification_records
        @classification_jobs = classification_jobs
        @classification_pipeline = Harassment::ClassificationPipeline.new(
          interaction_events: @interaction_events,
          classification_records: @classification_records,
          classification_jobs: @classification_jobs,
        )
        @message_ingestor = Harassment::MessageIngestor.new(
          interaction_events: @interaction_events,
          classification_pipeline: @classification_pipeline,
          classifier_version: @classifier_version,
        )
        @query_service = Harassment::QueryService.new(read_model: @read_model)
      end

      def message(event:, **)
        interaction_event = @message_ingestor.ingest(event)
        Logging.info(
          "harassment_interaction_enqueued",
          message_id: interaction_event.message_id,
          classifier_version: @classifier_version.to_s,
          target_count: interaction_event.target_user_ids.length,
        )
        interaction_event
      end

      def record_classification(event:, record:)
        @read_model.ingest(event:, record:)
      end

      def get_user_risk(user_id)
        @query_service.get_user_risk(user_id)
      end

      def get_pair_relationship(user_a, user_b)
        @query_service.get_pair_relationship(user_a, user_b)
      end

      def recent_incidents(channel_id, limit: 10)
        @query_service.recent_incidents(channel_id, limit:)
      end
    end
  end
end
