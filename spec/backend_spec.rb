require "backend"

class FakeRedis
  def initialize
    @sets = Hash.new { |hash, key| hash[key] = [] }
    @hashes = Hash.new { |hash, key| hash[key] = Hash.new(0) }
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
  end

  describe "#increment_user_karma" do
    it "increments a user's karma score" do
      expect(increment_user_karma(server_id, user_id, 2)).to eq(2)
      expect(get_user_karma(server_id, user_id)).to eq(2)
    end
  end

  describe "#set_user_karma" do
    it "sets a user's karma score" do
      expect(set_user_karma(server_id, user_id, 10)).to eq(10)
      expect(get_user_karma(server_id, user_id)).to eq(10)
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
