require_relative "../classification_job"

module Harassment
  module Repositories
    class ClassificationJobRepository
      def enqueue_unique(_job)
        raise NotImplementedError, "#{self.class} must implement #enqueue_unique"
      end

      def find(server_id:, message_id:, classifier_version:)
        raise NotImplementedError, "#{self.class} must implement #find"
      end

      def save(_job)
        raise NotImplementedError, "#{self.class} must implement #save"
      end

      def due_jobs(_as_of: Time.now.utc)
        raise NotImplementedError, "#{self.class} must implement #due_jobs"
      end
    end
  end
end
