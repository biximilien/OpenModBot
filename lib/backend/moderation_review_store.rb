require "time"
require_relative "../data_model/keys"
require_relative "../moderation/store_support"

module Backend
  module ModerationReviewStore
    include Moderation::StoreSupport

    def record_moderation_review(
      server_id:, channel_id:, message_id:, user_id:, strategy:, action:, shadow_mode:, flagged:,
      categories: {}, category_scores: {}, rewrite: nil, original_content: nil, automod_outcome: nil,
      created_at: Time.now.utc
    )
      entry = build_moderation_review_entry(
        server_id:, channel_id:, message_id:, user_id:, strategy:, action:, shadow_mode:, flagged:,
        categories:, category_scores:, rewrite:, original_content:, automod_outcome:, created_at:
      )

      @redis.lpush(DataModel::Keys.moderation_review(server_id), entry.to_json)
      @redis.ltrim(DataModel::Keys.moderation_review(server_id), 0,
                   Moderation::StoreSupport::MODERATION_REVIEW_LIMIT - 1)
      entry.to_h
    end

    def get_moderation_reviews(server_id, limit = 5, user_id: nil)
      review_limit = limit.to_i.clamp(1, Moderation::StoreSupport::MODERATION_REVIEW_LIMIT)
      entries = @redis.lrange(DataModel::Keys.moderation_review(server_id), 0,
                              Moderation::StoreSupport::MODERATION_REVIEW_LIMIT - 1).map do |payload|
        DataModel::ModerationReviewEntry.from_json(payload).to_h
      end
      entries = entries.select { |entry| entry[:user_id] == user_id.to_s } if user_id
      entries.first(review_limit)
    end

    def find_moderation_review(server_id, message_id)
      get_moderation_reviews(server_id, Moderation::StoreSupport::MODERATION_REVIEW_LIMIT).find do |entry|
        entry[:message_id] == message_id.to_s
      end
    end

    def clear_moderation_reviews(server_id)
      @redis.del(DataModel::Keys.moderation_review(server_id))
    end
  end
end
