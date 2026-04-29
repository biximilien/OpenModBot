require_relative "../../backend/karma_store"
require_relative "../../backend/moderation_review_store"
require_relative "../../backend/server_store"
require_relative "../../backend/watchlist_store"

module Moderation
  module Stores
    class RedisStore
      include Backend::KarmaStore
      include Backend::ModerationReviewStore
      include Backend::ServerStore
      include Backend::WatchlistStore

      attr_reader :redis

      def initialize(redis:)
        @redis = redis
      end
    end
  end
end
