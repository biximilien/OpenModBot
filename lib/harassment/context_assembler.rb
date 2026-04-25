require "set"

module Harassment
  class ContextAssembler
    DEFAULT_CHANNEL_LIMIT = 3
    DEFAULT_PAIR_LIMIT = 3

    def initialize(interaction_events:, channel_limit: DEFAULT_CHANNEL_LIMIT, pair_limit: DEFAULT_PAIR_LIMIT)
      @interaction_events = interaction_events
      @channel_limit = Integer(channel_limit)
      @pair_limit = Integer(pair_limit)
    end

    def build_for(event)
      participant_labels = build_participant_labels(event)

      {
        participant_labels: participant_labels,
        recent_channel_messages: serialize_events(
          @interaction_events.recent_in_channel(
            server_id: event.server_id,
            channel_id: event.channel_id,
            before: event.timestamp,
            limit: @channel_limit,
          ),
          participant_labels: participant_labels,
        ),
        recent_pair_interactions: serialize_events(
          @interaction_events.recent_between_participants(
            server_id: event.server_id,
            participant_ids: [event.author_id, *event.target_user_ids],
            before: event.timestamp,
            limit: @pair_limit,
          ),
          participant_labels: participant_labels,
        ),
      }
    end

    private

    def build_participant_labels(event)
      labels = {}
      labels[event.author_id] = "author"

      event.target_user_ids.each_with_index do |target_user_id, index|
        labels[target_user_id] = "target_#{index + 1}"
      end

      labels
    end

    def serialize_events(events, participant_labels:)
      events.map do |context_event|
        {
          timestamp: context_event.timestamp.iso8601,
          author_label: participant_label(context_event.author_id, participant_labels),
          target_labels: context_event.target_user_ids.map { |target_user_id| participant_label(target_user_id, participant_labels) },
          content: context_event.raw_content,
        }
      end
    end

    def participant_label(user_id, participant_labels)
      participant_labels.fetch(user_id.to_s) do
        "participant_#{participant_index(user_id, participant_labels)}"
      end
    end

    def participant_index(user_id, participant_labels)
      existing_ids = participant_labels.keys.to_set
      ordered_ids = existing_ids.to_a.sort
      ordered_ids.index(user_id.to_s)&.+(1) || ordered_ids.length + 1
    end
  end
end
