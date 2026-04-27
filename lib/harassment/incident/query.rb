require_relative "../classification/status"
require_relative "collection"
require_relative "incident"

module Harassment
  class IncidentQuery
    def initialize(interaction_events:, classification_records:)
      @interaction_events = interaction_events
      @classification_records = classification_records
    end

    def recent_incidents(server_id, channel_id, limit: 10, user_id: nil, since: nil)
      IncidentCollection.new(classified_incidents(server_id, channel_id:, since:))
        .recent(server_id:, channel_id:, limit:, user_id:, since:)
    end

    def incidents_for_author(server_id, user_id)
      IncidentCollection.new(classified_incidents(server_id, author_id: user_id)).for_author(server_id:, user_id:)
    end

    private

    def classified_incidents(server_id, channel_id: nil, author_id: nil, since: nil, limit: nil)
      @interaction_events
        .list_classified_for_server(server_id, channel_id:, author_id:, since:, limit:)
        .filter_map { |event| build_incident(event) }
    end

    def build_incident(event)
      record = @classification_records.latest_for_message(server_id: event.server_id, message_id: event.message_id)
      return nil unless record

      Incident.from_event_and_record(event:, record:)
    end
  end
end
