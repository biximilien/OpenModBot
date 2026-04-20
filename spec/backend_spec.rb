require "backend"

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
  end

  describe "#get_servers" do
    it "returns the servers" do
      add_server(server_id)
      expect(get_servers).to eq([server_id])
    end
  end
end
