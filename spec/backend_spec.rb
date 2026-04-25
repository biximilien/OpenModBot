require "backend"
require "json"

class FakeRedis
  def initialize
    @sets = Hash.new { |hash, key| hash[key] = [] }
    @hashes = Hash.new { |hash, key| hash[key] = Hash.new(0) }
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

  def hincrby(key, field, increment)
    @hashes[key][field.to_s] += increment
  end

  def hset(key, field, value)
    @hashes[key][field.to_s] = value
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

describe Backend do
  include Backend

  let(:server_id) { 123 }
  let(:user_id) { 456 }

  before do
    allow(Redis).to receive(:new).and_return(FakeRedis.new)
    initialize_backend
  end

  describe "#add_user_to_watch_list" do
    it "adds a user to the watch list" do
      add_user_to_watch_list(server_id, user_id)
      expect(get_watch_list_users(server_id)).to include(user_id)
    end
  end

  describe "#remove_user_from_watch_list" do
    it "removes a user from the watch list" do
      add_user_to_watch_list(server_id, user_id)
      remove_user_from_watch_list(server_id, user_id)
      expect(get_watch_list_users(server_id)).not_to include(user_id)
    end
  end

  describe "#get_watch_list_users" do
    it "returns the watch list users" do
      add_user_to_watch_list(server_id, user_id)
      expect(get_watch_list_users(server_id)).to eq([user_id])
    end
  end

  describe "#get_user_karma" do
    it "returns zero for users without karma events" do
      expect(get_user_karma(server_id, user_id)).to eq(0)
    end
  end

  describe "#decrement_user_karma" do
    it "decrements a user's karma score" do
      expect(decrement_user_karma(server_id, user_id)).to eq(-1)
      expect(get_user_karma(server_id, user_id)).to eq(-1)
    end

    it "supports custom decrement amounts" do
      expect(decrement_user_karma(server_id, user_id, 3)).to eq(-3)
      expect(get_user_karma(server_id, user_id)).to eq(-3)
    end

    it "records an audit event" do
      decrement_user_karma(server_id, user_id, 2, reason: "moderation_flag")

      expect(get_user_karma_history(server_id, user_id)).to include(
        hash_including(delta: -2, score: -2, source: "automated_infraction", reason: "moderation_flag"),
      )
    end

    it "rejects non-positive amounts" do
      expect { decrement_user_karma(server_id, user_id, 0) }.to raise_error(ArgumentError, "amount must be positive")
      expect { decrement_user_karma(server_id, user_id, -1) }.to raise_error(ArgumentError, "amount must be positive")
    end
  end

  describe "#increment_user_karma" do
    it "increments a user's karma score" do
      expect(increment_user_karma(server_id, user_id, 2)).to eq(2)
      expect(get_user_karma(server_id, user_id)).to eq(2)
    end

    it "records manual adjustment metadata" do
      increment_user_karma(server_id, user_id, 2, actor_id: 99)

      expect(get_user_karma_history(server_id, user_id)).to include(
        hash_including(delta: 2, score: 2, source: "manual_adjustment", actor_id: 99),
      )
    end

    it "rejects non-positive amounts" do
      expect { increment_user_karma(server_id, user_id, 0) }.to raise_error(ArgumentError, "amount must be positive")
      expect { increment_user_karma(server_id, user_id, -1) }.to raise_error(ArgumentError, "amount must be positive")
    end
  end

  describe "#set_user_karma" do
    it "sets a user's karma score" do
      expect(set_user_karma(server_id, user_id, 10)).to eq(10)
      expect(get_user_karma(server_id, user_id)).to eq(10)
    end

    it "records the delta from the previous score" do
      increment_user_karma(server_id, user_id, 3)
      set_user_karma(server_id, user_id, 0, actor_id: 99)

      expect(get_user_karma_history(server_id, user_id).first).to include(
        delta: -3,
        score: 0,
        source: "manual_reset",
        actor_id: 99,
      )
    end

    it "rejects non-integer scores" do
      expect { set_user_karma(server_id, user_id, "abc") }.to raise_error(ArgumentError, "score must be an integer")
    end
  end

  describe "#record_user_karma_event" do
    it "records a zero-delta audit event without changing the score" do
      set_user_karma(server_id, user_id, -5)
      record_user_karma_event(server_id, user_id, score: -5, source: "automod_timeout_applied")

      expect(get_user_karma(server_id, user_id)).to eq(-5)
      expect(get_user_karma_history(server_id, user_id).first).to include(
        delta: 0,
        score: -5,
        source: "automod_timeout_applied",
      )
    end

    it "rejects non-integer score or delta values" do
      expect { record_user_karma_event(server_id, user_id, score: "abc", source: "event") }.to raise_error(ArgumentError, "score must be an integer")
      expect { record_user_karma_event(server_id, user_id, score: -5, source: "event", delta: "abc") }.to raise_error(ArgumentError, "delta must be an integer")
    end
  end

  describe "#get_user_karma_history" do
    it "returns the most recent events first" do
      increment_user_karma(server_id, user_id, 1)
      decrement_user_karma(server_id, user_id, 2)

      expect(get_user_karma_history(server_id, user_id).map { |entry| entry[:delta] }).to eq([-2, 1])
    end

    it "honors the requested limit" do
      increment_user_karma(server_id, user_id, 1)
      increment_user_karma(server_id, user_id, 2)

      expect(get_user_karma_history(server_id, user_id, 1).length).to eq(1)
    end

    it "normalizes invalid limits" do
      increment_user_karma(server_id, user_id, 1)

      expect(get_user_karma_history(server_id, user_id, 0).length).to eq(1)
    end
  end

  describe "#add_server" do
    it "adds a server" do
      add_server(server_id)
      expect(get_servers).to include(server_id)
    end
  end

  describe "#remove_server" do
    it "removes a server" do
      add_server(server_id)
      remove_server(server_id)
      expect(get_servers).not_to include(server_id)
    end

    it "purges the server's moderation data" do
      add_server(server_id)
      add_user_to_watch_list(server_id, user_id)
      increment_user_karma(server_id, user_id, 2)
      record_user_karma_event(server_id, user_id, score: 2, source: "manual_note")

      remove_server(server_id)

      expect(get_watch_list_users(server_id)).to eq([])
      expect(get_user_karma(server_id, user_id)).to eq(0)
      expect(get_user_karma_history(server_id, user_id)).to eq([])
    end

    it "does not purge data from other servers" do
      other_server_id = 999
      add_server(server_id)
      add_server(other_server_id)
      increment_user_karma(server_id, user_id, 1)
      increment_user_karma(other_server_id, user_id, 3)

      remove_server(server_id)

      expect(get_servers).to include(other_server_id)
      expect(get_user_karma(other_server_id, user_id)).to eq(3)
      expect(get_user_karma_history(other_server_id, user_id).first).to include(score: 3)
    end
  end

  describe "#get_servers" do
    it "returns the servers" do
      add_server(server_id)
      expect(get_servers).to eq([server_id])
    end
  end
end
