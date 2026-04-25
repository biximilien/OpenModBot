require "time"
require_relative "classification_record"
require_relative "interaction_event"

module Harassment
  Incident = Data.define(
    :message_id,
    :server_id,
    :channel_id,
    :author_id,
    :target_user_ids,
    :intent,
    :target_type,
    :severity_score,
    :confidence,
    :classified_at,
  ) do
    def self.from_event_and_record(event:, record:)
      new(
        message_id: event.message_id,
        server_id: event.server_id,
        channel_id: event.channel_id,
        author_id: event.author_id,
        target_user_ids: event.target_user_ids,
        intent: record.classification[:intent],
        target_type: record.classification[:target_type],
        severity_score: record.severity_score,
        confidence: record.confidence,
        classified_at: record.classified_at,
      )
    end
  end
end
