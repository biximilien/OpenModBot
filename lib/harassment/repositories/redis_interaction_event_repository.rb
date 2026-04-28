require "json"
require_relative "interaction_event_repository"
require_relative "repository_keys"
require_relative "../../data_model/keys"

module Harassment
  module Repositories
    class RedisInteractionEventRepository < InteractionEventRepository
      include RepositoryKeys

      def initialize(redis:, key: DataModel::Keys.harassment_interaction_events)
        @redis = redis
        @key = key
      end

      def save(event)
        key = interaction_event_key(event.server_id, event.message_id)
        raise ArgumentError, "interaction event already exists for server_id=#{event.server_id} message_id=#{event.message_id}" if @redis.hget(@key, key)

        @redis.hset(@key, key, JSON.generate(serialize_event(event)))
        event
      end

      def find(message_id, server_id:)
        payload = @redis.hget(@key, interaction_event_key(server_id, message_id))
        payload ? deserialize_event(payload) : nil
      end

      def update_classification_status(message_id, status, server_id:)
        event = find(message_id, server_id:)
        return nil unless event

        updated = event.with_classification_status(status)
        @redis.hset(@key, interaction_event_key(updated.server_id, updated.message_id), JSON.generate(serialize_event(updated)))
        updated
      end

      def list_by_classification_status(status)
        normalized_status = normalize_status(status)
        all_events.select { |event| event.classification_status == normalized_status }
      end

      def list_classified_for_server(server_id, channel_id: nil, author_id: nil, since: nil, limit: nil)
        events = all_events.select do |event|
          event.server_id == server_id.to_s &&
            event.classification_status == ClassificationStatus::CLASSIFIED &&
            (channel_id.nil? || event.channel_id == channel_id.to_s) &&
            (author_id.nil? || event.author_id == author_id.to_s) &&
            (since.nil? || event.timestamp >= since.utc)
        end

        sorted = events.sort_by(&:timestamp)
        limit ? sorted.last(Integer(limit)) : sorted
      end

      def list_with_expired_content(as_of: Time.now.utc)
        all_events.select { |event| event.retention_expired?(as_of:) }
      end

      def redact_content(message_id, server_id:, redacted_at: Time.now.utc)
        event = find(message_id, server_id:)
        return nil unless event

        redacted = event.redact_content(redacted_at:)
        @redis.hset(@key, interaction_event_key(redacted.server_id, redacted.message_id), JSON.generate(serialize_event(redacted)))
        redacted
      end

      def recent_in_channel(server_id:, channel_id:, before:, limit:)
        all_events
          .select do |event|
            event.server_id == server_id.to_s &&
              event.channel_id == channel_id.to_s &&
              event.timestamp < before.utc
          end
          .sort_by(&:timestamp)
          .last(limit)
      end

      def recent_between_participants(server_id:, participant_ids:, before:, limit:)
        normalized_participant_ids = Array(participant_ids).map(&:to_s).to_set

        all_events
          .select do |event|
            event.server_id == server_id.to_s &&
              event.timestamp < before.utc &&
              interaction_involves_participants?(event, normalized_participant_ids)
          end
          .sort_by(&:timestamp)
          .last(limit)
      end

      private

      def all_events
        @redis.hgetall(@key).values.map { |payload| deserialize_event(payload) }
      end

      def serialize_event(event)
        event.to_h.merge(
          timestamp: event.timestamp.iso8601(9),
          content_retention_expires_at: event.content_retention_expires_at&.iso8601(9),
          content_redacted_at: event.content_redacted_at&.iso8601(9),
        )
      end

      def deserialize_event(payload)
        data = JSON.parse(payload, symbolize_names: true)
        InteractionEvent.build(**data)
      end

      def interaction_involves_participants?(event, participant_ids)
        event_participants = [event.author_id, *event.target_user_ids].to_set
        !(event_participants & participant_ids).empty?
      end

      def normalize_status(status)
        ClassificationStatus.normalize!(status, field_name: "classification_status")
      end
    end
  end
end
