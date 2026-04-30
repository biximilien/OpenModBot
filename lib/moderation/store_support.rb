require "time"
require_relative "../data_model/karma_event"
require_relative "../data_model/moderation_review_entry"

module Moderation
  module StoreSupport
    KARMA_AUDIT_LIMIT = 50
    MODERATION_REVIEW_LIMIT = 100
    MODERATION_REVIEW_SCHEMA_VERSION = 1

    private

    def build_karma_event(score:, source:, delta: 0, actor_id: nil, reason: nil, created_at: Time.now.utc.iso8601)
      DataModel::KarmaEvent.new(
        score: integer!(score, "score"),
        delta: integer!(delta, "delta"),
        source: source,
        actor_id: optional_integer(actor_id),
        reason: reason,
        created_at: created_at
      )
    end

    def build_moderation_review_entry(
      server_id:, channel_id:, message_id:, user_id:, strategy:, action:, shadow_mode:, flagged:,
      categories: {}, category_scores: {}, rewrite: nil, original_content: nil, automod_outcome: nil,
      created_at: Time.now.utc
    )
      DataModel::ModerationReviewEntry.new(
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
end
