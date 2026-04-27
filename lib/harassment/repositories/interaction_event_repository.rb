require_relative "../classification/status"
require_relative "../interaction/event"

module Harassment
  module Repositories
    class InteractionEventRepository
      def save(_event)
        raise NotImplementedError, "#{self.class} must implement #save"
      end

      def find(_message_id, server_id:)
        raise NotImplementedError, "#{self.class} must implement #find"
      end

      def update_classification_status(_message_id, _status, server_id:)
        raise NotImplementedError, "#{self.class} must implement #update_classification_status"
      end

      def list_by_classification_status(_status)
        raise NotImplementedError, "#{self.class} must implement #list_by_classification_status"
      end

      def list_with_expired_content(as_of: Time.now.utc)
        raise NotImplementedError, "#{self.class} must implement #list_with_expired_content"
      end

      def redact_content(_message_id, server_id:, redacted_at: Time.now.utc)
        raise NotImplementedError, "#{self.class} must implement #redact_content"
      end

      def recent_in_channel(server_id:, channel_id:, before:, limit:)
        raise NotImplementedError, "#{self.class} must implement #recent_in_channel"
      end

      def recent_between_participants(server_id:, participant_ids:, before:, limit:)
        raise NotImplementedError, "#{self.class} must implement #recent_between_participants"
      end
    end
  end
end
