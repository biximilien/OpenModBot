require_relative "../relationship_edge"

module Harassment
  module Repositories
    class RelationshipEdgeRepository
      def find(server_id:, source_user_id:, target_user_id:, score_version:)
        raise NotImplementedError, "#{self.class} must implement #find"
      end

      def save(_edge)
        raise NotImplementedError, "#{self.class} must implement #save"
      end

      def outgoing(server_id:, source_user_id:, score_version:)
        raise NotImplementedError, "#{self.class} must implement #outgoing"
      end

      def incoming(server_id:, target_user_id:, score_version:)
        raise NotImplementedError, "#{self.class} must implement #incoming"
      end
    end
  end
end
