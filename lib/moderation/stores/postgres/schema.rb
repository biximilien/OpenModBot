module Moderation
  module Stores
    module Postgres
      module Schema
        SCHEMA_STATEMENTS = [
          <<~SQL,
            CREATE TABLE IF NOT EXISTS moderation_servers (
              guild_id TEXT PRIMARY KEY
            )
          SQL
          <<~SQL,
            CREATE TABLE IF NOT EXISTS moderation_watchlist (
              guild_id TEXT NOT NULL,
              user_id TEXT NOT NULL,
              PRIMARY KEY (guild_id, user_id)
            )
          SQL
          <<~SQL,
            CREATE TABLE IF NOT EXISTS moderation_karma (
              guild_id TEXT NOT NULL,
              user_id TEXT NOT NULL,
              score INTEGER NOT NULL,
              PRIMARY KEY (guild_id, user_id)
            )
          SQL
          <<~SQL,
            CREATE TABLE IF NOT EXISTS moderation_karma_events (
              id BIGSERIAL PRIMARY KEY,
              guild_id TEXT NOT NULL,
              user_id TEXT NOT NULL,
              delta INTEGER NOT NULL,
              score INTEGER NOT NULL,
              source TEXT NOT NULL,
              actor_id TEXT,
              reason TEXT,
              created_at TIMESTAMPTZ NOT NULL
            )
          SQL
          <<~SQL
            CREATE TABLE IF NOT EXISTS moderation_reviews (
              id BIGSERIAL PRIMARY KEY,
              guild_id TEXT NOT NULL,
              channel_id TEXT NOT NULL,
              message_id TEXT NOT NULL,
              user_id TEXT NOT NULL,
              schema_version INTEGER NOT NULL,
              strategy TEXT NOT NULL,
              action TEXT NOT NULL,
              shadow_mode BOOLEAN NOT NULL,
              flagged BOOLEAN,
              categories JSONB NOT NULL DEFAULT '{}'::jsonb,
              category_scores JSONB NOT NULL DEFAULT '{}'::jsonb,
              rewrite TEXT,
              original_content TEXT,
              automod_outcome TEXT,
              created_at TIMESTAMPTZ NOT NULL
            )
          SQL
        ].freeze

        private

        def ensure_core_schema
          SCHEMA_STATEMENTS.each { |statement| exec(statement, []) }
        end
      end
    end
  end
end
