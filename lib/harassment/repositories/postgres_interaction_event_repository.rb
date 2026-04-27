require "json"
require "time"
require_relative "interaction_event_repository"
require_relative "postgres_helpers"

module Harassment
  module Repositories
    class PostgresInteractionEventRepository < InteractionEventRepository
      include PostgresHelpers

      REDACTED_CONTENT = "[REDACTED]".freeze

      def initialize(connection:)
        @connection = connection
      end

      def save(event)
        row = first_row(
          @connection.exec_params(
            <<~SQL,
              INSERT INTO interaction_events (
                guild_id,
                message_id,
                author_id,
                channel_id,
                target_user_ids,
                raw_content,
                classification_status,
                content_retention_expires_at,
                content_redacted_at,
                created_at
              )
              VALUES ($1, $2, $3, $4, $5::jsonb, $6, $7, $8, $9, $10)
              ON CONFLICT (guild_id, message_id) DO NOTHING
              RETURNING *
            SQL
            serialize_event(event),
          ),
        )
        raise ArgumentError, "interaction event already exists for server_id=#{event.server_id} message_id=#{event.message_id}" unless row

        deserialize_event(row)
      end

      def find(message_id, server_id:)
        row = first_row(
          @connection.exec_params(
            <<~SQL,
              SELECT *
              FROM interaction_events
              WHERE guild_id = $1
                AND message_id = $2
              LIMIT 1
            SQL
            [server_id.to_s, message_id.to_s],
          ),
        )
        row ? deserialize_event(row) : nil
      end

      def update_classification_status(message_id, status, server_id:)
        normalized_status = normalize_status(status)
        row = first_row(
          @connection.exec_params(
            <<~SQL,
              UPDATE interaction_events
              SET classification_status = $3
              WHERE guild_id = $1
                AND message_id = $2
              RETURNING *
            SQL
            [server_id.to_s, message_id.to_s, normalized_status],
          ),
        )
        row ? deserialize_event(row) : nil
      end

      def list_by_classification_status(status)
        normalized_status = normalize_status(status)
        rows(
          @connection.exec_params(
            <<~SQL,
              SELECT *
              FROM interaction_events
              WHERE classification_status = $1
              ORDER BY created_at ASC
            SQL
            [normalized_status],
          ),
        ).map { |row| deserialize_event(row) }
      end

      def list_classified_for_server(server_id, channel_id: nil, author_id: nil, since: nil, limit: nil)
        rows(
          @connection.exec_params(
            <<~SQL,
              SELECT *
              FROM interaction_events
              WHERE guild_id = $1
                AND classification_status = $2
                AND ($3::text IS NULL OR channel_id = $3)
                AND ($4::text IS NULL OR author_id = $4)
                AND ($5::timestamptz IS NULL OR created_at >= $5)
              ORDER BY created_at DESC
              LIMIT $6
            SQL
            [
              server_id.to_s,
              ClassificationStatus::CLASSIFIED,
              channel_id&.to_s,
              author_id&.to_s,
              since&.utc&.iso8601(9),
              limit ? Integer(limit) : nil,
            ],
          ),
        ).map { |row| deserialize_event(row) }.sort_by(&:timestamp)
      end

      def list_with_expired_content(as_of: Time.now.utc)
        rows(
          @connection.exec_params(
            <<~SQL,
              SELECT *
              FROM interaction_events
              WHERE content_retention_expires_at IS NOT NULL
                AND content_retention_expires_at <= $1
                AND content_redacted_at IS NULL
              ORDER BY created_at ASC
            SQL
            [as_of.utc.iso8601(9)],
          ),
        ).map { |row| deserialize_event(row) }
      end

      def redact_content(message_id, server_id:, redacted_at: Time.now.utc)
        row = first_row(
          @connection.exec_params(
            <<~SQL,
              UPDATE interaction_events
              SET raw_content = $3,
                  content_redacted_at = $4
              WHERE guild_id = $1
                AND message_id = $2
              RETURNING *
            SQL
            [server_id.to_s, message_id.to_s, REDACTED_CONTENT, redacted_at.utc.iso8601(9)],
          ),
        )
        row ? deserialize_event(row) : nil
      end

      def recent_in_channel(server_id:, channel_id:, before:, limit:)
        rows(
          @connection.exec_params(
            <<~SQL,
              SELECT *
              FROM interaction_events
              WHERE guild_id = $1
                AND channel_id = $2
                AND created_at < $3
              ORDER BY created_at DESC
              LIMIT $4
            SQL
            [server_id.to_s, channel_id.to_s, before.utc.iso8601(9), Integer(limit)],
          ),
        ).map { |row| deserialize_event(row) }.sort_by(&:timestamp)
      end

      def recent_between_participants(server_id:, participant_ids:, before:, limit:)
        rows(
          @connection.exec_params(
            <<~SQL,
              SELECT *
              FROM interaction_events
              WHERE guild_id = $1
                AND created_at < $2
                AND (
                  author_id = ANY($3::text[])
                  OR target_user_ids ?| $3::text[]
                )
              ORDER BY created_at DESC
              LIMIT $4
            SQL
            [server_id.to_s, before.utc.iso8601(9), Array(participant_ids).map(&:to_s), Integer(limit)],
          ),
        ).map { |row| deserialize_event(row) }.sort_by(&:timestamp)
      end

      private

      def serialize_event(event)
        [
          event.server_id,
          event.message_id,
          event.author_id,
          event.channel_id,
          JSON.generate(event.target_user_ids),
          event.raw_content,
          event.classification_status,
          event.content_retention_expires_at&.iso8601(9),
          event.content_redacted_at&.iso8601(9),
          event.timestamp.iso8601(9),
        ]
      end

      def deserialize_event(row)
        InteractionEvent.build(
          message_id: row.fetch("message_id"),
          server_id: row.fetch("guild_id"),
          channel_id: row.fetch("channel_id"),
          author_id: row.fetch("author_id"),
          target_user_ids: parse_target_user_ids(row.fetch("target_user_ids")),
          timestamp: row.fetch("created_at"),
          raw_content: row.fetch("raw_content"),
          classification_status: row.fetch("classification_status"),
          content_retention_expires_at: row["content_retention_expires_at"],
          content_redacted_at: row["content_redacted_at"],
        )
      end

      def parse_target_user_ids(value)
        parse_json_value(value)
      end

      def normalize_status(status)
        ClassificationStatus.normalize!(status, field_name: "classification_status")
      end
    end
  end
end
