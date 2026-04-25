require_relative "incident"
require_relative "decay_policy"
require_relative "relationship_edge"

module Harassment
  class ReadModel
    def initialize(decay_policy: DecayPolicy.new, score_version: "harassment-score-v1")
      @incidents_by_channel = Hash.new { |hash, key| hash[key] = [] }
      @edges = {}
      @processed_classifications = {}
      @decay_policy = decay_policy
      @score_version = score_version.to_s
    end

    def ingest(event:, record:)
      processed_key = projection_key(record.message_id, record.classifier_version)
      return @processed_classifications[processed_key] if @processed_classifications.key?(processed_key)

      incident = Incident.from_event_and_record(event:, record:)
      @incidents_by_channel[channel_key(incident.server_id, incident.channel_id)] << incident

      incident.target_user_ids.each do |target_user_id|
        edge = @edges.fetch(edge_key(incident.server_id, incident.author_id, target_user_id)) do
          RelationshipEdge.build(server_id: incident.server_id, source_user_id: incident.author_id, target_user_id: target_user_id, score_version: @score_version)
        end
        @edges[edge_key(incident.server_id, incident.author_id, target_user_id)] = update_edge(edge, incident)
      end

      @processed_classifications[processed_key] = incident
      incident
    end

    def recent_incidents(server_id, channel_id, limit: 10, user_id: nil, since: nil)
      incidents = @incidents_by_channel[channel_key(server_id, channel_id)]
      incidents = filter_incidents_for_user(incidents, user_id) if user_id
      incidents = incidents.select { |incident| incident.classified_at >= since.utc } if since

      incidents
        .sort_by(&:classified_at)
        .reverse
        .first(limit)
    end

    def get_pair_relationship(server_id, user_a, user_b, as_of: Time.now.utc)
      edge = @edges[edge_key(server_id, user_a, user_b)]
      edge&.decay_to(as_of:, decay_policy: @decay_policy)
    end

    def get_user_risk(server_id, user_id, as_of: Time.now.utc)
      edges = outgoing_relationships(server_id, user_id, as_of:)
      return 0.0 if edges.empty?

      edges.sum(&:hostility_score)
    end

    def outgoing_relationships(server_id, user_id, as_of: Time.now.utc)
      normalized_server_id = server_id.to_s
      source_user_id = user_id.to_s
      @edges.values
            .select { |edge| edge.server_id == normalized_server_id && edge.source_user_id == source_user_id }
            .map { |edge| edge.decay_to(as_of:, decay_policy: @decay_policy) }
    end

    def incoming_relationships(server_id, user_id, as_of: Time.now.utc)
      normalized_server_id = server_id.to_s
      target_user_id = user_id.to_s
      @edges.values
            .select { |edge| edge.server_id == normalized_server_id && edge.target_user_id == target_user_id }
            .map { |edge| edge.decay_to(as_of:, decay_policy: @decay_policy) }
    end

    def incidents_for_author(server_id, user_id)
      normalized_server_id = server_id.to_s
      author_id = user_id.to_s
      @incidents_by_channel.values.flatten.select { |incident| incident.server_id == normalized_server_id && incident.author_id == author_id }
    end

    private

    def filter_incidents_for_user(incidents, user_id)
      normalized_user_id = user_id.to_s
      incidents.select do |incident|
        incident.author_id == normalized_user_id || incident.target_user_ids.include?(normalized_user_id)
      end
    end

    def edge_key(server_id, source_user_id, target_user_id)
      "#{server_id}:#{source_user_id}:#{target_user_id}"
    end

    def channel_key(server_id, channel_id)
      "#{server_id}:#{channel_id}"
    end

    def projection_key(message_id, classifier_version)
      normalized_version =
        case classifier_version
        when ClassifierVersion then classifier_version.value
        else ClassifierVersion.build(classifier_version).value
        end

      "#{message_id}:#{normalized_version}"
    end

    def update_edge(edge, incident)
      decayed_edge = edge.decay_to(as_of: incident.classified_at, decay_policy: @decay_policy)

      RelationshipEdge.build(
        server_id: decayed_edge.server_id,
        source_user_id: decayed_edge.source_user_id,
        target_user_id: decayed_edge.target_user_id,
        score_version: decayed_edge.score_version,
        hostility_score: decayed_edge.hostility_score + incident.severity_score * incident.confidence,
        positive_score: decayed_edge.positive_score,
        interaction_count: decayed_edge.interaction_count + 1,
        last_interaction_at: incident.classified_at,
      )
    end
  end
end
