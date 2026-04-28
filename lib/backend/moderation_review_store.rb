require "time"
require_relative "../data_model/keys"
require_relative "../data_model/moderation_review_entry"

module Backend
  module ModerationReviewStore
    MODERATION_REVIEW_LIMIT = 100
    MODERATION_REVIEW_SCHEMA_VERSION = 1

    def record_moderation_review(server_id:, channel_id:, message_id:, user_id:, strategy:, action:, shadow_mode:, flagged:, categories: {}, category_scores: {}, rewrite: nil, original_content: nil, automod_outcome: nil, created_at: Time.now.utc)
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
        automod_outcome: automod_outcome,
      )

      @redis.lpush(DataModel::Keys.moderation_review(server_id), entry.to_json)
      @redis.ltrim(DataModel::Keys.moderation_review(server_id), 0, MODERATION_REVIEW_LIMIT - 1)
      entry.to_h
    end

    def get_moderation_reviews(server_id, limit = 5, user_id: nil)
      review_limit = limit.to_i.clamp(1, MODERATION_REVIEW_LIMIT)
      entries = @redis.lrange(DataModel::Keys.moderation_review(server_id), 0, MODERATION_REVIEW_LIMIT - 1).map do |payload|
        DataModel::ModerationReviewEntry.from_json(payload).to_h
      end
      entries = entries.select { |entry| entry[:user_id] == user_id.to_s } if user_id
      entries.first(review_limit)
    end

    def find_moderation_review(server_id, message_id)
      get_moderation_reviews(server_id, MODERATION_REVIEW_LIMIT).find do |entry|
        entry[:message_id] == message_id.to_s
      end
    end

    def clear_moderation_reviews(server_id)
      @redis.del(DataModel::Keys.moderation_review(server_id))
      true
    end

    private

    def normalize_hash(value)
      return {} unless value

      value.to_h.transform_keys do |key|
        key.to_s
      end
    end
  end
end
