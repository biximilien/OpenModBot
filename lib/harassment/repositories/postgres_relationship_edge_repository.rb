require "time"
require_relative "relationship_edge_repository"

module Harassment
  module Repositories
    class PostgresRelationshipEdgeRepository < RelationshipEdgeRepository
      def initialize(connection:)
        @connection = connection
      end

      def find(server_id:, source_user_id:, target_user_id:, score_version:)
        row = first_row(
          @connection.exec_params(
            <<~SQL,
              SELECT *
              FROM relationship_edges
              WHERE guild_id = $1
                AND source_user_id = $2
                AND target_user_id = $3
                AND score_version = $4
              LIMIT 1
            SQL
            [server_id.to_s, source_user_id.to_s, target_user_id.to_s, score_version.to_s],
          ),
        )
        row ? deserialize_edge(row) : nil
      end

      def save(edge)
        row = first_row(
          @connection.exec_params(
            <<~SQL,
              INSERT INTO relationship_edges (
                guild_id,
                source_user_id,
                target_user_id,
                score_version,
                hostility_score,
                positive_score,
                interaction_count,
                last_interaction_at
              )
              VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
              ON CONFLICT (guild_id, source_user_id, target_user_id, score_version)
              DO UPDATE SET hostility_score = EXCLUDED.hostility_score,
                            positive_score = EXCLUDED.positive_score,
                            interaction_count = EXCLUDED.interaction_count,
                            last_interaction_at = EXCLUDED.last_interaction_at
              RETURNING *
            SQL
            serialize_edge(edge),
          ),
        )
        deserialize_edge(row)
      end

      def outgoing(server_id:, source_user_id:, score_version:)
        rows(
          @connection.exec_params(
            <<~SQL,
              SELECT *
              FROM relationship_edges
              WHERE guild_id = $1
                AND source_user_id = $2
                AND score_version = $3
              ORDER BY target_user_id ASC
            SQL
            [server_id.to_s, source_user_id.to_s, score_version.to_s],
          ),
        ).map { |row| deserialize_edge(row) }
      end

      def incoming(server_id:, target_user_id:, score_version:)
        rows(
          @connection.exec_params(
            <<~SQL,
              SELECT *
              FROM relationship_edges
              WHERE guild_id = $1
                AND target_user_id = $2
                AND score_version = $3
              ORDER BY source_user_id ASC
            SQL
            [server_id.to_s, target_user_id.to_s, score_version.to_s],
          ),
        ).map { |row| deserialize_edge(row) }
      end

      private

      def serialize_edge(edge)
        [
          edge.server_id,
          edge.source_user_id,
          edge.target_user_id,
          edge.score_version,
          edge.hostility_score,
          edge.positive_score,
          edge.interaction_count,
          edge.last_interaction_at&.iso8601(9),
        ]
      end

      def deserialize_edge(row)
        RelationshipEdge.build(
          server_id: row.fetch("guild_id"),
          source_user_id: row.fetch("source_user_id"),
          target_user_id: row.fetch("target_user_id"),
          score_version: row.fetch("score_version"),
          hostility_score: row.fetch("hostility_score"),
          positive_score: row.fetch("positive_score"),
          interaction_count: row.fetch("interaction_count"),
          last_interaction_at: row.fetch("last_interaction_at"),
        )
      end

      def first_row(result)
        rows(result).first
      end

      def rows(result)
        result.respond_to?(:to_a) ? result.to_a : Array(result)
      end
    end
  end
end
