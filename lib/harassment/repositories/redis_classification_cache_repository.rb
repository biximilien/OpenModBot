require "json"
require "time"
require_relative "../../data_model/keys"
require_relative "../classification_record"
require_relative "classification_cache_repository"

module Harassment
  module Repositories
    class RedisClassificationCacheRepository < ClassificationCacheRepository
      def initialize(redis:, key: DataModel::Keys.harassment_classification_cache)
        @redis = redis
        @key = key
      end

      def fetch(cache_key, at: Time.now.utc)
        payload = @redis.hget(@key, cache_key)
        return nil unless payload

        entry = JSON.parse(payload, symbolize_names: true)
        expires_at = Time.parse(entry.fetch(:expires_at)).utc
        return hydrate_record(entry.fetch(:record)) if expires_at > at.utc

        @redis.hdel(@key, cache_key) if @redis.respond_to?(:hdel)
        nil
      end

      def store(cache_key, record, expires_at:)
        payload = {
          expires_at: expires_at.utc.iso8601,
          record: serialize_record(record),
        }
        @redis.hset(@key, cache_key, JSON.generate(payload))
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
          server_id: payload.fetch(:server_id),
          message_id: payload.fetch(:message_id),
          classifier_version: payload.fetch(:classifier_version),
          model_version: payload.fetch(:model_version),
          prompt_version: payload.fetch(:prompt_version),
          classification: payload.fetch(:classification),
          severity_score: payload.fetch(:severity_score),
          confidence: payload.fetch(:confidence),
          classified_at: payload.fetch(:classified_at),
        )
      end
    end
  end
end
