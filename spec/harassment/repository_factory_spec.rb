require "harassment/repository_factory"
require_relative "../support/fake_redis"

describe Harassment::RepositoryFactory do
  it "uses in-memory repositories when no backend or redis client is provided" do
    factory = described_class.new(backend: nil)

    expect(factory.interaction_events).to be_a(Harassment::Repositories::InMemoryInteractionEventRepository)
    expect(factory.classification_records).to be_a(Harassment::Repositories::InMemoryClassificationRecordRepository)
    expect(factory.classification_jobs).to be_a(Harassment::Repositories::InMemoryClassificationJobRepository)
    expect(factory.classification_cache).to be_a(Harassment::Repositories::InMemoryClassificationCacheRepository)
    expect(factory.server_rate_limits).to be_a(Harassment::Repositories::InMemoryServerRateLimitRepository)
  end

  it "uses redis repositories when redis is available and no backend is provided" do
    factory = described_class.new(backend: nil, redis: FakeRedis.new)

    expect(factory.interaction_events).to be_a(Harassment::Repositories::RedisInteractionEventRepository)
    expect(factory.classification_records).to be_a(Harassment::Repositories::RedisClassificationRecordRepository)
    expect(factory.classification_jobs).to be_a(Harassment::Repositories::RedisClassificationJobRepository)
    expect(factory.classification_cache).to be_a(Harassment::Repositories::RedisClassificationCacheRepository)
    expect(factory.server_rate_limits).to be_a(Harassment::Repositories::RedisServerRateLimitRepository)
  end

  it "returns the Postgres interaction repository and keeps later repositories explicit" do
    factory = described_class.new(backend: "postgres", connection: Object.new)

    expect(factory.interaction_events).to be_a(Harassment::Repositories::PostgresInteractionEventRepository)
    expect { factory.classification_records }.to raise_error(NotImplementedError, /Postgres harassment classification-record repositories are not implemented yet/)
  end
end
