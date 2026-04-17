require "backend"

class FakeRedis
  def initialize
    @sets = Hash.new { |hash, key| hash[key] = [] }
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
