require "json"
require "time"
require_relative "../../data_model/karma_event"
require_relative "../../data_model/moderation_review_entry"

module Moderation
  module Stores
    # rubocop:disable Metrics/ClassLength
    class PostgresStore
      KARMA_AUDIT_LIMIT = 50
      MODERATION_REVIEW_LIMIT = 100
      MODERATION_REVIEW_SCHEMA_VERSION = 1
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
            payload JSONB NOT NULL,
            created_at TIMESTAMPTZ NOT NULL
          )
        SQL
        <<~SQL
          CREATE TABLE IF NOT EXISTS moderation_reviews (
            id BIGSERIAL PRIMARY KEY,
            guild_id TEXT NOT NULL,
            message_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            payload JSONB NOT NULL,
            created_at TIMESTAMPTZ NOT NULL
          )
        SQL
      ].freeze

      def initialize(connection:, ensure_schema: true)
        @connection = connection
        ensure_core_schema if ensure_schema
      end

      def add_user_to_watch_list(server_id, user_id)
        exec(<<~SQL, [server_id.to_s, user_id.to_s])
          INSERT INTO moderation_watchlist (guild_id, user_id)
          VALUES ($1, $2)
          ON CONFLICT DO NOTHING
        SQL
      end

      def remove_user_from_watch_list(server_id, user_id)
        exec("DELETE FROM moderation_watchlist WHERE guild_id = $1 AND user_id = $2", [server_id.to_s, user_id.to_s])
      end

      def get_watch_list_users(server_id)
        rows(exec("SELECT user_id FROM moderation_watchlist WHERE guild_id = $1 ORDER BY user_id", [server_id.to_s]))
          .map { |row| row.fetch("user_id").to_i }
      end

      def get_user_karma(server_id, user_id)
        row = first_row(exec(
                          "SELECT score FROM moderation_karma WHERE guild_id = $1 AND user_id = $2 LIMIT 1",
                          [server_id.to_s, user_id.to_s]
                        ))
        row ? row.fetch("score").to_i : 0
      end

      def decrement_user_karma(
        server_id, user_id, amount = 1, source: "automated_infraction", actor_id: nil, reason: nil
      )
        validated_amount = positive_integer!(amount, "amount")
        change_user_karma(server_id, user_id, -validated_amount, source:, actor_id:, reason:)
      end

      def increment_user_karma(server_id, user_id, amount = 1, source: "manual_adjustment", actor_id: nil, reason: nil)
        validated_amount = positive_integer!(amount, "amount")
        change_user_karma(server_id, user_id, validated_amount, source:, actor_id:, reason:)
      end

      def set_user_karma(server_id, user_id, score, source: "manual_reset", actor_id: nil, reason: nil)
        validated_score = integer!(score, "score")
        previous_score = get_user_karma(server_id, user_id)
        write_user_karma(server_id, user_id, validated_score)
        record_user_karma_event(
          server_id,
          user_id,
          score: validated_score,
          delta: validated_score - previous_score,
          source:,
          actor_id:,
          reason:
        )
        validated_score
      end

      def record_user_karma_event(server_id, user_id, score:, source:, delta: 0, actor_id: nil, reason: nil)
        event = DataModel::KarmaEvent.new(
          score: integer!(score, "score"),
          delta: integer!(delta, "delta"),
          source: source,
          actor_id: optional_integer(actor_id),
          reason: reason,
          created_at: Time.now.utc.iso8601
        )
        exec(<<~SQL, [server_id.to_s, user_id.to_s, event.to_json, event.created_at])
          INSERT INTO moderation_karma_events (guild_id, user_id, payload, created_at)
          VALUES ($1, $2, $3::jsonb, $4)
        SQL
        event.to_h.compact
      end

      def get_user_karma_history(server_id, user_id, limit = 5)
        history_limit = limit.to_i.clamp(1, KARMA_AUDIT_LIMIT)
        rows(exec(<<~SQL, [server_id.to_s, user_id.to_s, history_limit]))
          SELECT payload
          FROM moderation_karma_events
          WHERE guild_id = $1 AND user_id = $2
          ORDER BY created_at DESC, id DESC
          LIMIT $3
        SQL
          .map { |row| DataModel::KarmaEvent.from_json(row.fetch("payload")).to_h.compact }
      end

      def add_server(server_id)
        exec(<<~SQL, [server_id.to_s])
          INSERT INTO moderation_servers (guild_id)
          VALUES ($1)
          ON CONFLICT DO NOTHING
        SQL
      end

      def remove_server(server_id)
        normalized_server_id = server_id.to_s
        exec("DELETE FROM moderation_servers WHERE guild_id = $1", [normalized_server_id])
        exec("DELETE FROM moderation_watchlist WHERE guild_id = $1", [normalized_server_id])
        exec("DELETE FROM moderation_karma WHERE guild_id = $1", [normalized_server_id])
        exec("DELETE FROM moderation_karma_events WHERE guild_id = $1", [normalized_server_id])
        exec("DELETE FROM moderation_reviews WHERE guild_id = $1", [normalized_server_id])
      end

      def servers
        rows(exec("SELECT guild_id FROM moderation_servers ORDER BY guild_id", [])).map do |row|
          row.fetch("guild_id").to_i
        end
      end

      def record_moderation_review(
        server_id:, channel_id:, message_id:, user_id:, strategy:, action:, shadow_mode:, flagged:,
        categories: {}, category_scores: {}, rewrite: nil, original_content: nil, automod_outcome: nil,
        created_at: Time.now.utc
      )
        entry = DataModel::ModerationReviewEntry.new(
          schema_version: MODERATION_REVIEW_SCHEMA_VERSION,
          created_at: created_at.utc.iso8601,
          server_id: server_id.to_s,
          channel_id: channel_id.to_s,
          message_id: message_id.to_s,
          user_id: user_id.to_s,
          strategy: strategy,
          action: action,
          shadow_mode: shadow_mode,
          flagged: flagged,
          categories: normalize_hash(categories),
          category_scores: normalize_hash(category_scores),
          rewrite: rewrite,
          original_content: original_content,
          automod_outcome: automod_outcome
        )
        exec(<<~SQL, [server_id.to_s, message_id.to_s, user_id.to_s, entry.to_json, entry.created_at])
          INSERT INTO moderation_reviews (guild_id, message_id, user_id, payload, created_at)
          VALUES ($1, $2, $3, $4::jsonb, $5)
        SQL
        entry.to_h
      end

      def get_moderation_reviews(server_id, limit = 5, user_id: nil)
        review_limit = limit.to_i.clamp(1, MODERATION_REVIEW_LIMIT)
        params = [server_id.to_s, review_limit]
        user_filter = ""
        if user_id
          user_filter = " AND user_id = $3"
          params << user_id.to_s
        end

        rows(exec(<<~SQL, params))
          SELECT payload
          FROM moderation_reviews
          WHERE guild_id = $1#{user_filter}
          ORDER BY created_at DESC, id DESC
          LIMIT $2
        SQL
          .map { |row| DataModel::ModerationReviewEntry.from_json(row.fetch("payload")).to_h }
      end

      def find_moderation_review(server_id, message_id)
        get_moderation_reviews(server_id, MODERATION_REVIEW_LIMIT).find do |entry|
          entry[:message_id] == message_id.to_s
        end
      end

      def clear_moderation_reviews(server_id)
        exec("DELETE FROM moderation_reviews WHERE guild_id = $1", [server_id.to_s])
      end

      private

      def change_user_karma(server_id, user_id, delta, source:, actor_id:, reason:)
        score = get_user_karma(server_id, user_id) + delta
        write_user_karma(server_id, user_id, score)
        record_user_karma_event(server_id, user_id, score:, delta:, source:, actor_id:, reason:)
        score
      end

      def write_user_karma(server_id, user_id, score)
        exec(<<~SQL, [server_id.to_s, user_id.to_s, score])
          INSERT INTO moderation_karma (guild_id, user_id, score)
          VALUES ($1, $2, $3)
          ON CONFLICT (guild_id, user_id)
          DO UPDATE SET score = EXCLUDED.score
        SQL
      end

      def ensure_core_schema
        SCHEMA_STATEMENTS.each { |statement| exec(statement, []) }
      end

      def exec(sql, params)
        @connection.exec_params(sql, params)
      end

      def first_row(result)
        rows(result).first
      end

      def rows(result)
        result.respond_to?(:to_a) ? result.to_a : Array(result)
      end

      def normalize_hash(value)
        return {} unless value

        value.to_h.transform_keys(&:to_sym)
      end

      def optional_integer(value)
        value&.to_i
      end

      def positive_integer!(value, name)
        integer = integer!(value, name)
        raise ArgumentError, "#{name} must be positive" unless integer.positive?

        integer
      end

      def integer!(value, name)
        Integer(value)
      rescue ArgumentError, TypeError
        raise ArgumentError, "#{name} must be an integer"
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
