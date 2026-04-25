require_relative "classifier_version"
require_relative "classification_pipeline"
require_relative "interaction_event"
require_relative "retention_policy"

module Harassment
  class MessageIngestor
    def initialize(interaction_events:, classification_pipeline:, retention_policy: RetentionPolicy.new, classifier_version:)
      @interaction_events = interaction_events
      @classification_pipeline = classification_pipeline
      @retention_policy = retention_policy
      @classifier_version = classifier_version.is_a?(ClassifierVersion) ? classifier_version : ClassifierVersion.build(classifier_version)
    end

    def ingest(event)
      interaction_event = InteractionEvent.build(
        message_id: event.message.id,
        server_id: event.server.id,
        channel_id: event.channel.id,
        author_id: event.user.id,
        target_user_ids: target_user_ids(event),
        timestamp: event.message.timestamp,
        raw_content: event.message.content,
        content_retention_expires_at: @retention_policy.retention_expires_at(event.message.timestamp),
      )

      @interaction_events.save(interaction_event)
      @classification_pipeline.enqueue(
        message_id: interaction_event.message_id,
        classifier_version: @classifier_version,
        enqueued_at: interaction_event.timestamp,
      )

      interaction_event
    rescue ArgumentError => e
      return @interaction_events.find(event.message.id) if duplicate_interaction_event?(e)

      raise
    end

    private

    def target_user_ids(event)
      Array(event.message.mentions).map(&:id)
    end

    def duplicate_interaction_event?(error)
      error.message.start_with?("interaction event already exists")
    end
  end
end
