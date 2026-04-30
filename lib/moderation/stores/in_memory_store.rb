require "time"
require_relative "../store_support"

module Moderation
  module Stores
    class InMemoryStore
      include StoreSupport

      def initialize
        @servers = {}
        @watchlists = Hash.new { |store, server_id| store[server_id] = {} }
        @karma = Hash.new { |store, server_id| store[server_id] = {} }
        @karma_history = Hash.new { |store, key| store[key] = [] }
        @moderation_reviews = Hash.new { |store, server_id| store[server_id] = [] }
      end

      def add_user_to_watch_list(server_id, user_id)
        @watchlists[normalize_id(server_id)][normalize_id(user_id)] = true
      end

      def remove_user_from_watch_list(server_id, user_id)
        @watchlists[normalize_id(server_id)].delete(normalize_id(user_id))
      end

      def get_watch_list_users(server_id)
        @watchlists[normalize_id(server_id)].keys.map(&:to_i)
      end

      def get_user_karma(server_id, user_id)
        @karma[normalize_id(server_id)].fetch(normalize_id(user_id), 0)
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
        event = build_karma_event(score:, delta:, source:, actor_id:, reason:)
        history = @karma_history[karma_history_key(server_id, user_id)]
        history.unshift(event)
        history.slice!(KARMA_AUDIT_LIMIT..)
        event.to_h.compact
      end

      def get_user_karma_history(server_id, user_id, limit = 5)
        history_limit = limit.to_i.clamp(1, KARMA_AUDIT_LIMIT)
        @karma_history[karma_history_key(server_id, user_id)].first(history_limit).map { |event| event.to_h.compact }
      end

      def add_server(server_id)
        @servers[normalize_id(server_id)] = true
      end

      def remove_server(server_id)
        normalized_server_id = normalize_id(server_id)
        @servers.delete(normalized_server_id)
        @watchlists.delete(normalized_server_id)
        @karma.delete(normalized_server_id)
        @moderation_reviews.delete(normalized_server_id)
        @karma_history.delete_if { |(history_server_id, _user_id), _history| history_server_id == normalized_server_id }
      end

      def servers
        @servers.keys.map(&:to_i)
      end

      def record_moderation_review(
        server_id:, channel_id:, message_id:, user_id:, strategy:, action:, shadow_mode:, flagged:,
        categories: {}, category_scores: {}, rewrite: nil, original_content: nil, automod_outcome: nil,
        created_at: Time.now.utc
      )
        entry = build_moderation_review_entry(
          server_id:, channel_id:, message_id:, user_id:, strategy:, action:, shadow_mode:, flagged:,
          categories:, category_scores:, rewrite:, original_content:, automod_outcome:, created_at:
        )
        reviews = @moderation_reviews[normalize_id(server_id)]
        reviews.unshift(entry)
        reviews.slice!(MODERATION_REVIEW_LIMIT..)
        entry.to_h
      end

      def get_moderation_reviews(server_id, limit = 5, user_id: nil)
        review_limit = limit.to_i.clamp(1, MODERATION_REVIEW_LIMIT)
        entries = @moderation_reviews[normalize_id(server_id)].map(&:to_h)
        entries = entries.select { |entry| entry[:user_id] == user_id.to_s } if user_id
        entries.first(review_limit)
      end

      def find_moderation_review(server_id, message_id)
        get_moderation_reviews(server_id, MODERATION_REVIEW_LIMIT).find do |entry|
          entry[:message_id] == message_id.to_s
        end
      end

      def clear_moderation_reviews(server_id)
        @moderation_reviews[normalize_id(server_id)] = []
      end

      private

      def change_user_karma(server_id, user_id, delta, source:, actor_id:, reason:)
        score = get_user_karma(server_id, user_id) + delta
        write_user_karma(server_id, user_id, score)
        record_user_karma_event(server_id, user_id, score:, delta:, source:, actor_id:, reason:)
        score
      end

      def write_user_karma(server_id, user_id, score)
        @karma[normalize_id(server_id)][normalize_id(user_id)] = score
      end

      def karma_history_key(server_id, user_id)
        [normalize_id(server_id), normalize_id(user_id)]
      end

      def normalize_id(value)
        value.to_s
      end
    end
  end
end
