require_relative "interaction_event_repository"
require_relative "repository_keys"

module Harassment
  module Repositories
    class InMemoryInteractionEventRepository < InteractionEventRepository
      include RepositoryKeys

      def initialize
        @events = {}
      end

      def save(event)
        key = interaction_event_key(event.server_id, event.message_id)
        if @events.key?(key)
          raise ArgumentError, "interaction event already exists for server_id=#{event.server_id} message_id=#{event.message_id}"
        end

        @events[key] = event
      end

      def find(message_id, server_id:)
        @events[interaction_event_key(server_id, message_id)]
      end

      def update_classification_status(message_id, status, server_id:)
        event = find(message_id, server_id:)
        return nil unless event

        updated = event.with_classification_status(status)
        @events[interaction_event_key(event.server_id, event.message_id)] = updated
      end

      def list_by_classification_status(status)
        normalized_status = normalize_status(status)
        @events.values.select { |event| event.classification_status == normalized_status }
      end

      def list_classified_for_server(server_id, channel_id: nil, author_id: nil, since: nil, limit: nil)
        events = @events.values.select do |event|
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
        @events.values.select { |event| event.retention_expired?(as_of:) }
      end

      def redact_content(message_id, server_id:, redacted_at: Time.now.utc)
        event = find(message_id, server_id:)
        return nil unless event

        redacted = event.redact_content(redacted_at:)
        @events[interaction_event_key(event.server_id, event.message_id)] = redacted
      end

      def recent_in_channel(server_id:, channel_id:, before:, limit:)
        @events.values
               .select do |event|
                 event.server_id == server_id.to_s &&
                   event.channel_id == channel_id.to_s &&
                   event.timestamp < before.utc
               end
               .sort_by(&:timestamp)
               .last(limit)
      end

      def recent_between_participants(server_id:, participant_ids:, before:, limit:)
        normalized_participant_ids = Array(participant_ids).to_set(&:to_s)

        @events.values
               .select do |event|
                 event.server_id == server_id.to_s &&
                   event.timestamp < before.utc &&
                   interaction_involves_participants?(event, normalized_participant_ids)
               end
               .sort_by(&:timestamp)
               .last(limit)
      end

      private

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
