require_relative "../classifier/version"

module Harassment
  module Repositories
    module RepositoryKeys
      private

      def interaction_event_key(server_id, message_id)
        "#{server_id}:#{message_id}"
      end

      def classification_key(server_id, message_id, classifier_version)
        "#{server_id}:#{message_id}:#{normalized_classifier_version_value(classifier_version)}"
      end

      def normalized_classifier_version_value(classifier_version)
        case classifier_version
        when ClassifierVersion then classifier_version.value
        else ClassifierVersion.build(classifier_version).value
        end
      end
    end
  end
end
