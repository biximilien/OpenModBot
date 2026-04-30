require "time"
require_relative "../data_model/keys"
require_relative "../moderation/store_support"
require_relative "redis_scripts"

module Backend
  module KarmaStore
    include Moderation::StoreSupport

    def get_user_karma(server_id, user_id)
      @redis.hget(DataModel::Keys.karma(server_id), user_id).to_i
    end

    def decrement_user_karma(server_id, user_id, amount = 1, source: "automated_infraction", actor_id: nil, reason: nil)
      validated_amount = positive_integer!(amount, "amount")
      change_user_karma(server_id, user_id, -validated_amount, source:, actor_id:, reason:)
    end

    def increment_user_karma(server_id, user_id, amount = 1, source: "manual_adjustment", actor_id: nil, reason: nil)
      validated_amount = positive_integer!(amount, "amount")
      change_user_karma(server_id, user_id, validated_amount, source:, actor_id:, reason:)
    end

    def set_user_karma(server_id, user_id, score, source: "manual_reset", actor_id: nil, reason: nil)
      validated_score = integer!(score, "score")
      created_at = Time.now.utc.iso8601
      @redis.eval(
        RedisScripts::SET_KARMA_WITH_AUDIT,
        keys: [DataModel::Keys.karma(server_id), DataModel::Keys.karma_history(server_id, user_id)],
        argv: [user_id.to_s, validated_score, source, optional_redis_arg(actor_id), optional_redis_arg(reason),
               created_at, Moderation::StoreSupport::KARMA_AUDIT_LIMIT]
      )
    end

    def record_user_karma_event(server_id, user_id, score:, source:, delta: 0, actor_id: nil, reason: nil)
      validated_score = integer!(score, "score")
      validated_delta = integer!(delta, "delta")
      created_at = Time.now.utc.iso8601
      @redis.eval(
        RedisScripts::RECORD_KARMA_EVENT,
        keys: [DataModel::Keys.karma_history(server_id, user_id)],
        argv: [validated_score, validated_delta, source, created_at, optional_redis_arg(actor_id),
               optional_redis_arg(reason), Moderation::StoreSupport::KARMA_AUDIT_LIMIT]
      )
    end

    def get_user_karma_history(server_id, user_id, limit = 5)
      history_limit = limit.to_i.clamp(1, Moderation::StoreSupport::KARMA_AUDIT_LIMIT)
      @redis.lrange(DataModel::Keys.karma_history(server_id, user_id), 0, history_limit - 1).map do |entry|
        DataModel::KarmaEvent.from_json(entry).to_h.compact
      end
    end

    private

    def change_user_karma(server_id, user_id, delta, source:, actor_id:, reason:)
      created_at = Time.now.utc.iso8601
      @redis.eval(
        RedisScripts::INCREMENT_KARMA_WITH_AUDIT,
        keys: [DataModel::Keys.karma(server_id), DataModel::Keys.karma_history(server_id, user_id)],
        argv: [user_id.to_s, delta.to_i, source, optional_redis_arg(actor_id), optional_redis_arg(reason), created_at,
               Moderation::StoreSupport::KARMA_AUDIT_LIMIT]
      )
    end

    def optional_redis_arg(value)
      value.nil? ? "" : value.to_s
    end
  end
end
