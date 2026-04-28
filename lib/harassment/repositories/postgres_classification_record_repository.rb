require "json"
require "time"
require_relative "classification_record_repository"
require_relative "postgres_helpers"

module Harassment
  module Repositories
    class PostgresClassificationRecordRepository < ClassificationRecordRepository
      include PostgresHelpers

      def initialize(connection:)
        @connection = connection
      end

      def save(record)
        row = first_row(
          @connection.exec_params(
            <<~SQL,
              INSERT INTO classification_records (
                guild_id,
                message_id,
                classifier_version,
                model_version,
                prompt_version,
                classification,
                severity_score,
                confidence,
                classified_at
              )
              VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7, $8, $9)
              ON CONFLICT (guild_id, message_id, classifier_version) DO NOTHING
              RETURNING *
            SQL
            serialize_record(record),
          ),
        )
        unless row
          raise ArgumentError, "classification record already exists for #{record.server_id}:#{record.message_id}:#{record.classifier_version.value}"
        end

        deserialize_record(row)
      end

      def find(server_id:, message_id:, classifier_version:)
        row = first_row(
          @connection.exec_params(
            <<~SQL,
              SELECT *
              FROM classification_records
              WHERE guild_id = $1
                AND message_id = $2
                AND classifier_version = $3
              LIMIT 1
            SQL
            [server_id.to_s, message_id.to_s, normalize_classifier_version(classifier_version)],
          ),
        )
        row ? deserialize_record(row) : nil
      end

      def all_for_message(server_id:, message_id:)
        rows(
          @connection.exec_params(
            <<~SQL,
              SELECT *
              FROM classification_records
              WHERE guild_id = $1
                AND message_id = $2
              ORDER BY classified_at ASC
            SQL
            [server_id.to_s, message_id.to_s],
          ),
        ).map { |row| deserialize_record(row) }
      end

      def latest_for_message(server_id:, message_id:)
        row = first_row(
          @connection.exec_params(
            <<~SQL,
              SELECT *
              FROM classification_records
              WHERE guild_id = $1
                AND message_id = $2
              ORDER BY classified_at DESC
              LIMIT 1
            SQL
            [server_id.to_s, message_id.to_s],
          ),
        )
        row ? deserialize_record(row) : nil
      end

      private

      def serialize_record(record)
        [
          record.server_id,
          record.message_id,
          record.classifier_version.value,
          record.model_version,
          record.prompt_version,
          JSON.generate(record.classification),
          record.severity_score,
          record.confidence,
          record.classified_at.iso8601(9),
        ]
      end

      def deserialize_record(row)
        ClassificationRecord.build(
          server_id: row.fetch("guild_id"),
          message_id: row.fetch("message_id"),
          classifier_version: row.fetch("classifier_version"),
          model_version: row.fetch("model_version"),
          prompt_version: row.fetch("prompt_version"),
          classification: parse_classification(row.fetch("classification")),
          severity_score: row.fetch("severity_score"),
          confidence: row.fetch("confidence"),
          classified_at: row.fetch("classified_at"),
        )
      end

      def parse_classification(value)
        deep_symbolize(parse_json_value(value))
      end
    end
  end
end
