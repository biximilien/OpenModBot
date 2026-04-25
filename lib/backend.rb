require "redis"
require_relative "../environment"
require_relative "backend/redis_scripts"
require_relative "data_model/keys"
require_relative "data_model/karma_event"

module Backend
  KARMA_AUDIT_LIMIT = 50

  def initialize_backend
    @redis ||= Redis.new(url: Environment.redis_url)
    raise "Redis connection failed" unless @redis.ping == "PONG"
  end

  def add_user_to_watch_list(server_id, user_id)
    @redis.sadd(DataModel::Keys.watchlist(server_id), user_id)
  end

  def remove_user_from_watch_list(server_id, user_id)
    @redis.srem(DataModel::Keys.watchlist(server_id), user_id.to_s)
  end

  def get_watch_list_users(server_id)
    @redis.smembers(DataModel::Keys.watchlist(server_id)).map(&:to_i)
  end

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
      argv: [user_id.to_s, validated_score, source, optional_redis_arg(actor_id), optional_redis_arg(reason), created_at, KARMA_AUDIT_LIMIT],
    )
  end

  def record_user_karma_event(server_id, user_id, score:, source:, delta: 0, actor_id: nil, reason: nil)
    validated_score = integer!(score, "score")
    validated_delta = integer!(delta, "delta")
    created_at = Time.now.utc.iso8601
    @redis.eval(
      RedisScripts::RECORD_KARMA_EVENT,
      keys: [DataModel::Keys.karma_history(server_id, user_id)],
      argv: [validated_score, validated_delta, source, created_at, optional_redis_arg(actor_id), optional_redis_arg(reason), KARMA_AUDIT_LIMIT],
    )
  end

  def get_user_karma_history(server_id, user_id, limit = 5)
    history_limit = [[limit.to_i, 1].max, KARMA_AUDIT_LIMIT].min
    @redis.lrange(DataModel::Keys.karma_history(server_id, user_id), 0, history_limit - 1).map do |entry|
      DataModel::KarmaEvent.from_json(entry).to_h.compact
    end
  end

  def add_server(server_id)
    @redis.sadd(DataModel::Keys.servers, server_id)
  end

  def remove_server(server_id)
    @redis.srem(DataModel::Keys.servers, server_id)
    purge_server_data(server_id)
  end

  def get_servers
    @redis.smembers(DataModel::Keys.servers).map(&:to_i)
  end

  private

  def change_user_karma(server_id, user_id, delta, source:, actor_id:, reason:)
    created_at = Time.now.utc.iso8601
    @redis.eval(
      RedisScripts::INCREMENT_KARMA_WITH_AUDIT,
      keys: [DataModel::Keys.karma(server_id), DataModel::Keys.karma_history(server_id, user_id)],
      argv: [user_id.to_s, delta.to_i, source, optional_redis_arg(actor_id), optional_redis_arg(reason), created_at, KARMA_AUDIT_LIMIT],
    )
  end

  def optional_redis_arg(value)
    value.nil? ? "" : value.to_s
  end

  def purge_server_data(server_id)
    delete_key(DataModel::Keys.watchlist(server_id))
    delete_key(DataModel::Keys.karma(server_id))

    @redis.scan_each(match: DataModel::Keys.karma_history_pattern(server_id)) do |key|
      delete_key(key)
    end
  end

  def delete_key(key)
    @redis.del(key)
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
