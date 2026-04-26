require_relative "relationship_edge_repository"

module Harassment
  module Repositories
    class InMemoryRelationshipEdgeRepository < RelationshipEdgeRepository
      def initialize
        @edges = {}
      end

      def find(server_id:, source_user_id:, target_user_id:, score_version:)
        @edges[edge_key(server_id, source_user_id, target_user_id, score_version)]
      end

      def save(edge)
        @edges[edge_key(edge.server_id, edge.source_user_id, edge.target_user_id, edge.score_version)] = edge
        edge
      end

      def outgoing(server_id:, source_user_id:, score_version:)
        normalized_server_id = server_id.to_s
        normalized_source_user_id = source_user_id.to_s
        normalized_score_version = score_version.to_s

        @edges.values.select do |edge|
          edge.server_id == normalized_server_id &&
            edge.source_user_id == normalized_source_user_id &&
            edge.score_version == normalized_score_version
        end
      end

      def incoming(server_id:, target_user_id:, score_version:)
        normalized_server_id = server_id.to_s
        normalized_target_user_id = target_user_id.to_s
        normalized_score_version = score_version.to_s

        @edges.values.select do |edge|
          edge.server_id == normalized_server_id &&
            edge.target_user_id == normalized_target_user_id &&
            edge.score_version == normalized_score_version
        end
      end

      private

      def edge_key(server_id, source_user_id, target_user_id, score_version)
        "#{server_id}:#{source_user_id}:#{target_user_id}:#{score_version}"
      end
    end
  end
end
