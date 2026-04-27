require "json"
require "time"
require_relative "../classification/record"
require_relative "classification_cache_repository"
require_relative "postgres_helpers"

module Harassment
  module Repositories
    class PostgresClassificationCacheRepository < ClassificationCacheRepository
      include PostgresHelpers

      def initialize(connection:)
        @connection = connection
      end

      def fetch(cache_key, at: Time.now.utc)
        row = first_row(
          @connection.exec_params(
            <<~SQL,
              SELECT *
              FROM classification_cache_entries
              WHERE cache_key = $1
              LIMIT 1
            SQL
            [cache_key.to_s],
          ),
        )
        return nil unless row

        expires_at = Time.parse(row.fetch("expires_at")).utc
        return hydrate_record(parse_record_payload(row.fetch("record_payload"))) if expires_at > at.utc

        @connection.exec_params(
          <<~SQL,
            DELETE FROM classification_cache_entries
            WHERE cache_key = $1
          SQL
          [cache_key.to_s],
        )
        nil
      end

      def store(cache_key, record, expires_at:)
        @connection.exec_params(
          <<~SQL,
            INSERT INTO classification_cache_entries (
              cache_key,
              record_payload,
              expires_at
            )
            VALUES ($1, $2::jsonb, $3)
            ON CONFLICT (cache_key)
            DO UPDATE SET record_payload = EXCLUDED.record_payload,
                          expires_at = EXCLUDED.expires_at
          SQL
          [cache_key.to_s, JSON.generate(serialize_record(record)), expires_at.utc.iso8601],
        )
        record
      end

      private

      def serialize_record(record)
        {
          server_id: record.server_id,
          message_id: record.message_id,
          classifier_version: record.classifier_version.value,
          model_version: record.model_version,
          prompt_version: record.prompt_version,
          classification: record.classification,
          severity_score: record.severity_score,
          confidence: record.confidence,
          classified_at: record.classified_at.iso8601,
        }
      end

      def hydrate_record(payload)
        ClassificationRecord.build(
          server_id: payload.fetch("server_id"),
          message_id: payload.fetch("message_id"),
          classifier_version: payload.fetch("classifier_version"),
          model_version: payload.fetch("model_version"),
          prompt_version: payload.fetch("prompt_version"),
          classification: deep_symbolize(payload.fetch("classification")),
          severity_score: payload.fetch("severity_score"),
          confidence: payload.fetch("confidence"),
          classified_at: payload.fetch("classified_at"),
        )
      end

      def parse_record_payload(value)
        parse_json_value(value)
      end
    end
  end
end
