require_relative "classification_status"
require_relative "incident"

module Harassment
  class IncidentQuery
    def initialize(interaction_events:, classification_records:)
      @interaction_events = interaction_events
      @classification_records = classification_records
    end

    def recent_incidents(server_id, channel_id, limit: 10, user_id: nil, since: nil)
      incidents = classified_incidents_for_server(server_id)
      incidents = incidents.select { |incident| incident.channel_id == channel_id.to_s }
      incidents = filter_incidents_for_user(incidents, user_id) if user_id
      incidents = incidents.select { |incident| incident.classified_at >= since.utc } if since

      incidents
        .sort_by(&:classified_at)
        .reverse
        .first(limit)
    end

    def incidents_for_author(server_id, user_id)
      classified_incidents_for_server(server_id)
        .select { |incident| incident.author_id == user_id.to_s }
        .sort_by(&:classified_at)
    end

    private

    def classified_incidents_for_server(server_id)
      @interaction_events
        .list_by_classification_status(ClassificationStatus::CLASSIFIED)
        .select { |event| event.server_id == server_id.to_s }
        .filter_map { |event| build_incident(event) }
    end

    def build_incident(event)
      record = @classification_records.latest_for_message(server_id: event.server_id, message_id: event.message_id)
      return nil unless record

      Incident.from_event_and_record(event:, record:)
    end

    def filter_incidents_for_user(incidents, user_id)
      normalized_user_id = user_id.to_s
      incidents.select do |incident|
        incident.author_id == normalized_user_id || incident.target_user_ids.include?(normalized_user_id)
      end
    end
  end
end
