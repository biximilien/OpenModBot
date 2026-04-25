require "json"
require_relative "classification_job_repository"
require_relative "../../data_model/keys"

module Harassment
  module Repositories
    class RedisClassificationJobRepository < ClassificationJobRepository
      def initialize(redis:, key: DataModel::Keys.harassment_classification_jobs)
        @redis = redis
        @key = key
      end

      def enqueue_unique(job)
        key = repository_key(job.server_id, job.message_id, job.classifier_version)
        payload = @redis.hget(@key, key)
        return deserialize_job(payload) if payload

        @redis.hset(@key, key, JSON.generate(serialize_job(job)))
        job
      end

      def find(server_id:, message_id:, classifier_version:)
        payload = @redis.hget(@key, repository_key(server_id, message_id, classifier_version))
        payload ? deserialize_job(payload) : nil
      end

      def save(job)
        @redis.hset(@key, repository_key(job.server_id, job.message_id, job.classifier_version), JSON.generate(serialize_job(job)))
        job
      end

      def due_jobs(as_of: Time.now.utc)
        all_jobs
          .select { |job| job.available_at <= as_of && retryable_or_pending?(job.status) }
          .sort_by(&:available_at)
      end

      private

      def all_jobs
        @redis.hgetall(@key).values.map { |payload| deserialize_job(payload) }
      end

      def retryable_or_pending?(status)
        [ClassificationStatus::PENDING, ClassificationStatus::FAILED_RETRYABLE].include?(status)
      end

      def repository_key(server_id, message_id, classifier_version)
        normalized_server_id = server_id.to_s
        normalized_version =
          case classifier_version
          when ClassifierVersion then classifier_version.value
          else ClassifierVersion.build(classifier_version).value
          end

        "#{normalized_server_id}:#{message_id}:#{normalized_version}"
      end

      def serialize_job(job)
        job.to_h.merge(
          classifier_version: job.classifier_version.value,
          available_at: job.available_at.iso8601(9),
          enqueued_at: job.enqueued_at.iso8601(9),
          updated_at: job.updated_at.iso8601(9),
        )
      end

      def deserialize_job(payload)
        data = JSON.parse(payload, symbolize_names: true)
        ClassificationJob.build(**data)
      end
    end
  end
end
