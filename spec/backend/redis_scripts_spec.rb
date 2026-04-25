require "backend/redis_scripts"

describe Backend::RedisScripts do
  describe "script constants" do
    it "defines the increment karma script" do
      expect(described_class::INCREMENT_KARMA_WITH_AUDIT).to include('redis.call("HINCRBY"')
    end

    it "defines the set karma script" do
      expect(described_class::SET_KARMA_WITH_AUDIT).to include('redis.call("HSET"')
    end

    it "defines the record-only karma event script" do
      expect(described_class::RECORD_KARMA_EVENT).to include('redis.call("LPUSH"')
    end
  end
end
