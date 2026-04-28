require_relative "../incident/incident"
require_relative "../incident/collection"
require_relative "decay_policy"
require_relative "../relationship/edge"
require_relative "../repositories/in_memory_relationship_edge_repository"

module Harassment
  class ReadModel
    attr_reader :score_version

    def initialize(
      decay_policy: DecayPolicy.new,
      score_version: "harassment-score-v1",
      edge_repository: Repositories::InMemoryRelationshipEdgeRepository.new
    )
      @incidents_by_channel = Hash.new { |hash, key| hash[key] = [] }
      @processed_classifications = {}
      @decay_policy = decay_policy
      @score_version = score_version.to_s
      @edge_repository = edge_repository
    end

    def ingest(event:, record:)
      processed_key = projection_key(record.message_id, record.classifier_version)
      return @processed_classifications[processed_key] if @processed_classifications.key?(processed_key)

      incident = Incident.from_event_and_record(event:, record:)
      @incidents_by_channel[channel_key(incident.server_id, incident.channel_id)] << incident

      incident.target_user_ids.each do |target_user_id|
        edge =
          @edge_repository.find(
            server_id: incident.server_id,
            source_user_id: incident.author_id,
            target_user_id: target_user_id,
            score_version: @score_version,
          ) || RelationshipEdge.build(
            server_id: incident.server_id,
            source_user_id: incident.author_id,
            target_user_id: target_user_id,
            score_version: @score_version,
          )
        @edge_repository.save(update_edge(edge, incident))
      end

      @processed_classifications[processed_key] = incident
      incident
    end

    def recent_incidents(server_id, channel_id, limit: 10, user_id: nil, since: nil)
      IncidentCollection.new(@incidents_by_channel[channel_key(server_id, channel_id)])
                        .recent(server_id:, channel_id:, limit:, user_id:, since:)
    end

    def get_pair_relationship(server_id, user_a, user_b, as_of: Time.now.utc)
      edge = @edge_repository.find(server_id:, source_user_id: user_a, target_user_id: user_b, score_version: @score_version)
      edge&.decay_to(as_of:, decay_policy: @decay_policy)
    end

    def get_user_risk(server_id, user_id, as_of: Time.now.utc)
      edges = outgoing_relationships(server_id, user_id, as_of:)
      return 0.0 if edges.empty?

      edges.sum(&:hostility_score)
    end

    def outgoing_relationships(server_id, user_id, as_of: Time.now.utc)
      @edge_repository
        .outgoing(server_id:, source_user_id: user_id, score_version: @score_version)
        .map { |edge| edge.decay_to(as_of:, decay_policy: @decay_policy) }
    end

    def incoming_relationships(server_id, user_id, as_of: Time.now.utc)
      @edge_repository
        .incoming(server_id:, target_user_id: user_id, score_version: @score_version)
        .map { |edge| edge.decay_to(as_of:, decay_policy: @decay_policy) }
    end

    def incidents_for_author(server_id, user_id)
      IncidentCollection.new(@incidents_by_channel.values.flatten).for_author(server_id:, user_id:)
    end

    private

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
        hostility_score: decayed_edge.hostility_score + (incident.severity_score * incident.confidence),
        positive_score: decayed_edge.positive_score,
        interaction_count: decayed_edge.interaction_count + 1,
        last_interaction_at: incident.classified_at,
      )
    end
  end
end
