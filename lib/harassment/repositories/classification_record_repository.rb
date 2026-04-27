require_relative "../classification/record"

module Harassment
  module Repositories
    class ClassificationRecordRepository
      def save(_record)
        raise NotImplementedError, "#{self.class} must implement #save"
      end

      def find(server_id:, message_id:, classifier_version:)
        raise NotImplementedError, "#{self.class} must implement #find"
      end

      def all_for_message(server_id:, message_id:)
        raise NotImplementedError, "#{self.class} must implement #all_for_message"
      end

      def latest_for_message(server_id:, message_id:)
        raise NotImplementedError, "#{self.class} must implement #latest_for_message"
      end
    end
  end
end
