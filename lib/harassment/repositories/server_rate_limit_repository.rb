module Harassment
  module Repositories
    class ServerRateLimitRepository
      def fetch(_server_id)
        raise NotImplementedError, "#{self.class} must implement #fetch"
      end

      def save(_server_id, _timestamps)
        raise NotImplementedError, "#{self.class} must implement #save"
      end
    end
  end
end
