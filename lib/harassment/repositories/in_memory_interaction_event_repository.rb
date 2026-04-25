require_relative "interaction_event_repository"

module Harassment
  module Repositories
    class InMemoryInteractionEventRepository < InteractionEventRepository
      def initialize
        @events = {}
      end

      def save(event)
        message_id = event.message_id
        raise ArgumentError, "interaction event already exists for message_id=#{message_id}" if @events.key?(message_id)

        @events[message_id] = event
      end

      def find(message_id)
        @events[message_id.to_s]
      end

      def update_classification_status(message_id, status)
        event = find(message_id)
        return nil unless event

        updated = event.with_classification_status(status)
        @events[event.message_id] = updated
      end

      def list_by_classification_status(status)
        normalized_status = normalize_status(status)
        @events.values.select { |event| event.classification_status == normalized_status }
      end

      def list_with_expired_content(as_of: Time.now.utc)
        @events.values.select { |event| event.retention_expired?(as_of:) }
      end

      def redact_content(message_id, redacted_at: Time.now.utc)
        event = find(message_id)
        return nil unless event

        redacted = event.redact_content(redacted_at:)
        @events[event.message_id] = redacted
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
        normalized_participant_ids = Array(participant_ids).map(&:to_s).to_set

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
        return status if ClassificationStatus::ALL.include?(status)

        InteractionEvent.build(
          message_id: "validation",
          server_id: "validation",
          channel_id: "validation",
          author_id: "validation",
          raw_content: "validation",
          classification_status: status,
        ).classification_status
      end
    end
  end
end
