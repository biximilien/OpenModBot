require "json"

class FakeRedis
  def initialize
    @sets = Hash.new { |hash, key| hash[key] = [] }
    @hashes = Hash.new { |hash, key| hash[key] = {} }
    @lists = Hash.new { |hash, key| hash[key] = [] }
  end

  def ping
    "PONG"
  end

  def sadd(key, value)
    @sets[key] << value.to_s unless @sets[key].include?(value.to_s)
  end

  def srem(key, value)
    @sets[key].delete(value.to_s)
  end

  def smembers(key)
    @sets[key]
  end

  def hget(key, field)
    @hashes[key][field.to_s]
  end

  def hset(key, field, value)
    @hashes[key][field.to_s] = value
  end

  def hdel(key, field)
    @hashes[key].delete(field.to_s)
  end

  def hgetall(key)
    @hashes[key].dup
  end

  def hincrby(key, field, increment)
    @hashes[key][field.to_s] = @hashes[key].fetch(field.to_s, 0).to_i + increment
  end

  def lpush(key, value)
    @lists[key].unshift(value)
  end

  def ltrim(key, start, stop)
    @lists[key] = @lists[key][start..stop] || []
  end

  def lrange(key, start, stop)
    @lists[key][start..stop] || []
  end

  def del(*keys)
    keys.flatten.each do |key|
      @sets.delete(key)
      @hashes.delete(key)
      @lists.delete(key)
    end
  end

  def scan_each(match:)
    regex = Regexp.new("\\A" + Regexp.escape(match).gsub("\\*", ".*") + "\\z")
    all_keys.grep(regex).each { |key| yield key }
  end

  def eval(script, keys:, argv:)
    case script
    when Backend::RedisScripts::INCREMENT_KARMA_WITH_AUDIT
      eval_increment_karma_with_audit(keys, argv)
    when Backend::RedisScripts::SET_KARMA_WITH_AUDIT
      eval_set_karma_with_audit(keys, argv)
    when Backend::RedisScripts::RECORD_KARMA_EVENT
      eval_record_karma_event(keys, argv)
    else
      raise "Unsupported script"
    end
  end

  private

  def eval_increment_karma_with_audit(keys, argv)
    karma_key, history_key = keys
    user_id, delta, source, actor_id, reason, created_at, limit = argv
    score = hincrby(karma_key, user_id, delta.to_i)

    lpush(history_key, build_event_json(created_at:, delta: delta.to_i, score:, source:, actor_id:, reason:))
    ltrim(history_key, 0, limit.to_i - 1)
    score
  end

  def eval_set_karma_with_audit(keys, argv)
    karma_key, history_key = keys
    user_id, score, source, actor_id, reason, created_at, limit = argv
    previous = hget(karma_key, user_id).to_i
    hset(karma_key, user_id, score.to_i)

    lpush(
      history_key,
      build_event_json(created_at:, delta: score.to_i - previous, score: score.to_i, source:, actor_id:, reason:),
    )
    ltrim(history_key, 0, limit.to_i - 1)
    score.to_i
  end

  def eval_record_karma_event(keys, argv)
    history_key = keys.first
    score, delta, source, created_at, actor_id, reason, limit = argv

    lpush(
      history_key,
      build_event_json(created_at:, delta: delta.to_i, score: score.to_i, source:, actor_id:, reason:),
    )
    ltrim(history_key, 0, limit.to_i - 1)
    score.to_i
  end

  def build_event_json(created_at:, delta:, score:, source:, actor_id:, reason:)
    event = {
      created_at: created_at,
      delta: delta,
      score: score,
      source: source,
    }
    event[:actor_id] = actor_id.to_i unless actor_id.nil? || actor_id.empty?
    event[:reason] = reason unless reason.nil? || reason.empty?
    JSON.generate(event)
  end

  def all_keys
    (@sets.keys + @hashes.keys + @lists.keys).uniq
  end
end
