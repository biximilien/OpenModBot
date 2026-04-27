require_relative "../../../data_model/keys"
require_relative "../postgres_verification_helpers"

module Harassment
  module PostgresVerification
    class SpotChecks
      include PostgresVerificationHelpers

      def initialize(redis:, interaction_event_repository:, classification_record_repository:, classification_job_repository:)
        @redis = redis
        @interaction_event_repository = interaction_event_repository
        @classification_record_repository = classification_record_repository
        @classification_job_repository = classification_job_repository
      end

      def run(limit:)
        {
          interaction_events: spot_check_interaction_events(limit:),
          classification_records: spot_check_classification_records(limit:),
          classification_jobs: spot_check_classification_jobs(limit:),
        }
      end

      private

      def spot_check_interaction_events(limit:)
        source_events = redis_rows_for(@redis, DataModel::Keys.harassment_interaction_events).take(limit)
        build_spot_check_summary(source_events) do |data|
          postgres_event = @interaction_event_repository.find(
            data.fetch("message_id"),
            server_id: data.fetch("server_id"),
          )
          next [false, { message_id: data.fetch("message_id").to_s, reason: "missing" }] unless postgres_event

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

          compare_record(
            identifier: { message_id: data.fetch("message_id").to_s },
            expected:,
            actual:,
          )
        end
      end

      def spot_check_classification_records(limit:)
        source_records = redis_rows_for(@redis, DataModel::Keys.harassment_classification_records).take(limit)
        build_spot_check_summary(source_records) do |data|
          postgres_record = @classification_record_repository.find(
            server_id: data.fetch("server_id"),
            message_id: data.fetch("message_id"),
            classifier_version: data.fetch("classifier_version"),
          )
          identifier = {
            server_id: data.fetch("server_id").to_s,
            message_id: data.fetch("message_id").to_s,
            classifier_version: data.fetch("classifier_version").to_s,
          }
          next [false, identifier.merge(reason: "missing")] unless postgres_record

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

          compare_record(identifier:, expected:, actual:)
        end
      end

      def spot_check_classification_jobs(limit:)
        source_jobs = redis_rows_for(@redis, DataModel::Keys.harassment_classification_jobs).take(limit)
        build_spot_check_summary(source_jobs) do |data|
          postgres_job = @classification_job_repository.find(
            server_id: data.fetch("server_id"),
            message_id: data.fetch("message_id"),
            classifier_version: data.fetch("classifier_version"),
          )
          identifier = {
            server_id: data.fetch("server_id").to_s,
            message_id: data.fetch("message_id").to_s,
            classifier_version: data.fetch("classifier_version").to_s,
          }
          next [false, identifier.merge(reason: "missing")] unless postgres_job

          expected = {
            status: data.fetch("status").to_s,
            attempt_count: data.fetch("attempt_count").to_i,
          }
          actual = {
            status: postgres_job.status,
            attempt_count: postgres_job.attempt_count,
          }

          compare_record(identifier:, expected:, actual:)
        end
      end
    end
  end
end
