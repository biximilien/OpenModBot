require_relative "server_rate_limit_repository"

module Harassment
  module Repositories
    class InMemoryServerRateLimitRepository < ServerRateLimitRepository
      def initialize
        @timestamps = {}
      end

      def fetch(server_id)
        @timestamps.fetch(server_id.to_s, []).dup
      end

      def save(server_id, timestamps)
        @timestamps[server_id.to_s] = timestamps.map(&:utc)
      end
    end
  end
end
