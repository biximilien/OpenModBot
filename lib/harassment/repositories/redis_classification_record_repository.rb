require "json"
require_relative "classification_record_repository"
require_relative "../../data_model/keys"

module Harassment
  module Repositories
    class RedisClassificationRecordRepository < ClassificationRecordRepository
      def initialize(redis:, key: DataModel::Keys.harassment_classification_records)
        @redis = redis
        @key = key
      end

      def save(record)
        key = repository_key(record.server_id, record.message_id, record.classifier_version)
        raise ArgumentError, "classification record already exists for #{key}" if @redis.hget(@key, key)

        @redis.hset(@key, key, JSON.generate(serialize_record(record)))
        record
      end

      def find(server_id:, message_id:, classifier_version:)
        payload = @redis.hget(@key, repository_key(server_id, message_id, classifier_version))
        payload ? deserialize_record(payload) : nil
      end

      def all_for_message(server_id:, message_id:)
        normalized_server_id = server_id.to_s
        normalized_message_id = message_id.to_s
        all_records.select { |record| record.server_id == normalized_server_id && record.message_id == normalized_message_id }.sort_by(&:classified_at)
      end

      def latest_for_message(server_id:, message_id:)
        all_for_message(server_id:, message_id:).last
      end

      private

      def all_records
        @redis.hgetall(@key).values.map { |payload| deserialize_record(payload) }
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

      def serialize_record(record)
        record.to_h.merge(
          classifier_version: record.classifier_version.value,
          classified_at: record.classified_at.iso8601(9),
        )
      end

      def deserialize_record(payload)
        data = JSON.parse(payload, symbolize_names: true)
        ClassificationRecord.build(**data)
      end
    end
  end
end
