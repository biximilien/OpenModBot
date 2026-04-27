require_relative "../../../data_model/keys"
require_relative "../postgres_verification_helpers"

module Harassment
  module PostgresVerification
    class KnownMessageChecks
      include PostgresVerificationHelpers

      def initialize(redis:, interaction_event_repository:, classification_record_repository:, classification_job_repository:)
        @redis = redis
        @interaction_event_repository = interaction_event_repository
        @classification_record_repository = classification_record_repository
        @classification_job_repository = classification_job_repository
      end

      def run(message_ids)
        Array(message_ids).map(&:to_s).uniq.each_with_object({}) do |message_id, summary|
          summary[message_id] = {
            interaction_event: verify_known_interaction_event(message_id),
            classification_records: verify_known_classification_records(message_id),
            classification_jobs: verify_known_classification_jobs(message_id),
          }
        end
      end

      private

      def verify_known_interaction_event(message_id)
        data = redis_rows_for(@redis, DataModel::Keys.harassment_interaction_events)
          .find { |row| row.fetch("message_id").to_s == message_id.to_s }
        return { found_in_redis: false, found_in_postgres: false, matches: false } unless data

        postgres_event = @interaction_event_repository.find(message_id, server_id: data.fetch("server_id"))
        return { found_in_redis: true, found_in_postgres: false, matches: false } unless postgres_event

        expected = {
          server_id: data.fetch("server_id").to_s,
          classification_status: data.fetch("classification_status").to_s,
          raw_content: data.fetch("raw_content").to_s,
        }
        actual = {
          server_id: postgres_event.server_id,
          classification_status: postgres_event.classification_status,
          raw_content: postgres_event.raw_content,
        }

        build_known_verification_result(expected:, actual:)
      end

      def verify_known_classification_records(message_id)
        records = redis_rows_for(@redis, DataModel::Keys.harassment_classification_records)
          .select { |data| data.fetch("message_id").to_s == message_id.to_s }

        build_known_collection_summary(records) do |data|
          postgres_record = @classification_record_repository.find(
            server_id: data.fetch("server_id"),
            message_id: data.fetch("message_id"),
            classifier_version: data.fetch("classifier_version"),
          )
          identifier = {
            server_id: data.fetch("server_id").to_s,
            classifier_version: data.fetch("classifier_version").to_s,
          }
          next missing_known_result(identifier) unless postgres_record

          expected = {
            model_version: data.fetch("model_version").to_s,
            prompt_version: data.fetch("prompt_version").to_s,
            severity_score: data.fetch("severity_score").to_f,
            confidence: data.fetch("confidence").to_f,
          }
          actual = {
            model_version: postgres_record.model_version,
            prompt_version: postgres_record.prompt_version,
            severity_score: postgres_record.severity_score,
            confidence: postgres_record.confidence,
          }

          build_known_verification_result(expected:, actual:, identifier:)
        end
      end

      def verify_known_classification_jobs(message_id)
        jobs = redis_rows_for(@redis, DataModel::Keys.harassment_classification_jobs)
          .select { |data| data.fetch("message_id").to_s == message_id.to_s }

        build_known_collection_summary(jobs) do |data|
          postgres_job = @classification_job_repository.find(
            server_id: data.fetch("server_id"),
            message_id: data.fetch("message_id"),
            classifier_version: data.fetch("classifier_version"),
          )
          identifier = {
            server_id: data.fetch("server_id").to_s,
            classifier_version: data.fetch("classifier_version").to_s,
          }
          next missing_known_result(identifier) unless postgres_job

          expected = {
            status: data.fetch("status").to_s,
            attempt_count: data.fetch("attempt_count").to_i,
          }
          actual = {
            status: postgres_job.status,
            attempt_count: postgres_job.attempt_count,
          }

          build_known_verification_result(expected:, actual:, identifier:)
        end
      end

      def build_known_collection_summary(rows)
        return { found_in_redis: false, found_in_postgres: false, matches: false, entries: [] } if rows.empty?

        entries = rows.map { |row| yield(row) }
        {
          found_in_redis: true,
          found_in_postgres: entries.any? { |entry| entry[:found_in_postgres] },
          matches: entries.all? { |entry| entry[:matches] },
          entries:,
        }
      end
    end
  end
end
