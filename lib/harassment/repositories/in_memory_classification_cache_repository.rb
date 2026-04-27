require_relative "../classification/record"
require_relative "classification_cache_repository"

module Harassment
  module Repositories
    class InMemoryClassificationCacheRepository < ClassificationCacheRepository
      def initialize
        @entries = {}
      end

      def fetch(cache_key, at: Time.now.utc)
        entry = @entries[cache_key]
        return nil unless entry

        return entry[:record] if entry[:expires_at] > at.utc

        @entries.delete(cache_key)
        nil
      end

      def store(cache_key, record, expires_at:)
        @entries[cache_key] = {
          record: record,
          expires_at: expires_at.utc,
        }
        record
      end
    end
  end
end
