require "moderation/stores/redis_store"
require_relative "../../support/fake_redis"
require_relative "../../support/shared_examples/moderation_store_contract"

describe Moderation::Stores::RedisStore do
  subject(:store) { described_class.new(redis:) }

  let(:redis) { FakeRedis.new }

  it_behaves_like "a moderation store"
end
