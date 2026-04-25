require_relative "incident"
require_relative "relationship_edge"

module Harassment
  class ReadModel
    def initialize
      @incidents_by_channel = Hash.new { |hash, key| hash[key] = [] }
      @edges = {}
    end

    def ingest(event:, record:)
      incident = Incident.from_event_and_record(event:, record:)
      @incidents_by_channel[incident.channel_id] << incident

      incident.target_user_ids.each do |target_user_id|
        edge = @edges.fetch(edge_key(incident.author_id, target_user_id)) do
          RelationshipEdge.build(source_user_id: incident.author_id, target_user_id: target_user_id)
        end
        @edges[edge_key(incident.author_id, target_user_id)] = update_edge(edge, incident)
      end

      incident
    end

    def recent_incidents(channel_id, limit: 10)
      @incidents_by_channel[channel_id.to_s]
        .sort_by(&:classified_at)
        .reverse
        .first(limit)
    end

    def get_pair_relationship(user_a, user_b)
      @edges[edge_key(user_a, user_b)]
    end

    def get_user_risk(user_id)
      source_user_id = user_id.to_s
      edges = @edges.values.select { |edge| edge.source_user_id == source_user_id }
      return 0.0 if edges.empty?

      edges.sum(&:hostility_score)
    end

    def outgoing_relationships(user_id)
      source_user_id = user_id.to_s
      @edges.values.select { |edge| edge.source_user_id == source_user_id }
    end

    private

    def edge_key(source_user_id, target_user_id)
      "#{source_user_id}:#{target_user_id}"
    end

    def update_edge(edge, incident)
      RelationshipEdge.build(
        source_user_id: edge.source_user_id,
        target_user_id: edge.target_user_id,
        hostility_score: edge.hostility_score + incident.severity_score * incident.confidence,
        positive_score: edge.positive_score,
        interaction_count: edge.interaction_count + 1,
        last_interaction_at: incident.classified_at,
      )
    end
  end
end
