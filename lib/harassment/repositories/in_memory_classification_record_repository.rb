require_relative "classification_record_repository"
require_relative "repository_keys"

module Harassment
  module Repositories
    class InMemoryClassificationRecordRepository < ClassificationRecordRepository
      include RepositoryKeys

      def initialize
        @records = {}
      end

      def save(record)
        key = classification_key(record.server_id, record.message_id, record.classifier_version)
        raise ArgumentError, "classification record already exists for #{key}" if @records.key?(key)

        @records[key] = record
      end

      def find(server_id:, message_id:, classifier_version:)
        @records[classification_key(server_id, message_id, classifier_version)]
      end

      def all_for_message(server_id:, message_id:)
        normalized_server_id = server_id.to_s
        normalized_message_id = message_id.to_s
        @records.values.select { |record| record.server_id == normalized_server_id && record.message_id == normalized_message_id }.sort_by(&:classified_at)
      end

      def latest_for_message(server_id:, message_id:)
        all_for_message(server_id:, message_id:).last
      end
    end
  end
end
