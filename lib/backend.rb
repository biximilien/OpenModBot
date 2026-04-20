require "redis"
require "json"
require "time"
require_relative "../environment"

module Backend
  KARMA_AUDIT_LIMIT = 50

  def initialize_backend
    @redis ||= Redis.new(url: Environment.redis_url)
    raise "Redis connection failed" unless @redis.ping == "PONG"
  end

  def add_user_to_watch_list(server_id, user_id)
    @redis.sadd("server_#{server_id}_users", user_id)
  end

  def remove_user_from_watch_list(server_id, user_id)
    @redis.srem("server_#{server_id}_users", user_id.to_s)
  end

  def get_watch_list_users(server_id)
    @redis.smembers("server_#{server_id}_users").map(&:to_i)
  end

  def get_user_karma(server_id, user_id)
    @redis.hget(karma_key(server_id), user_id).to_i
  end

  def decrement_user_karma(server_id, user_id, amount = 1, source: "automated_infraction", actor_id: nil, reason: nil)
    delta = -amount
    score = @redis.hincrby(karma_key(server_id), user_id, delta)
    record_karma_audit_event(server_id, user_id, delta:, score:, source:, actor_id:, reason:)
    score
  end

  def increment_user_karma(server_id, user_id, amount = 1, source: "manual_adjustment", actor_id: nil, reason: nil)
    score = @redis.hincrby(karma_key(server_id), user_id, amount)
    record_karma_audit_event(server_id, user_id, delta: amount, score:, source:, actor_id:, reason:)
    score
  end

  def set_user_karma(server_id, user_id, score, source: "manual_reset", actor_id: nil, reason: nil)
    previous_score = get_user_karma(server_id, user_id)
    @redis.hset(karma_key(server_id), user_id, score)
    record_karma_audit_event(server_id, user_id, delta: score - previous_score, score:, source:, actor_id:, reason:)
    score
  end

  def get_user_karma_history(server_id, user_id, limit = 5)
    history_limit = [[limit.to_i, 1].max, KARMA_AUDIT_LIMIT].min
    @redis.lrange(karma_history_key(server_id, user_id), 0, history_limit - 1).map do |entry|
      JSON.parse(entry, symbolize_names: true)
    end
  end

  def add_server(server_id)
    @redis.sadd("servers", server_id)
  end

  def remove_server(server_id)
    @redis.srem("servers", server_id)
  end

  def get_servers
    @redis.smembers("servers").map(&:to_i)
  end

  private

  def karma_key(server_id)
    "server_#{server_id}_karma"
  end

  def karma_history_key(server_id, user_id)
    "server_#{server_id}_user_#{user_id}_karma_history"
  end

  def record_karma_audit_event(server_id, user_id, delta:, score:, source:, actor_id:, reason:)
    event = {
      created_at: Time.now.utc.iso8601,
      delta: delta,
      score: score,
      source: source,
      actor_id: actor_id,
      reason: reason,
    }.compact

    key = karma_history_key(server_id, user_id)
    @redis.lpush(key, JSON.generate(event))
    @redis.ltrim(key, 0, KARMA_AUDIT_LIMIT - 1)
  end
end
