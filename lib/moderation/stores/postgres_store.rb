require_relative "../store_support"
require_relative "postgres/karma_store"
require_relative "postgres/review_store"
require_relative "postgres/schema"
require_relative "postgres/server_store"
require_relative "postgres/sql_support"
require_relative "postgres/watchlist_store"

module Moderation
  module Stores
    class PostgresStore
      include StoreSupport
      include Postgres::SqlSupport
      include Postgres::Schema
      include Postgres::ServerStore
      include Postgres::WatchlistStore
      include Postgres::KarmaStore
      include Postgres::ReviewStore

      def initialize(connection:, ensure_schema: true)
        @connection = connection
        ensure_core_schema if ensure_schema
      end
    end
  end
end
