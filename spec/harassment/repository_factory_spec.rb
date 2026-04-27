require "harassment/persistence/repository_factory"
require_relative "../support/fake_redis"

describe Harassment::RepositoryFactory do
  it "uses in-memory repositories when no backend or redis client is provided" do
    factory = described_class.new(backend: nil)

    expect(factory.interaction_events).to be_a(Harassment::Repositories::InMemoryInteractionEventRepository)
    expect(factory.classification_records).to be_a(Harassment::Repositories::InMemoryClassificationRecordRepository)
    expect(factory.classification_jobs).to be_a(Harassment::Repositories::InMemoryClassificationJobRepository)
    expect(factory.classification_cache).to be_a(Harassment::Repositories::InMemoryClassificationCacheRepository)
    expect(factory.server_rate_limits).to be_a(Harassment::Repositories::InMemoryServerRateLimitRepository)
    expect(factory.relationship_edges).to be_a(Harassment::Repositories::InMemoryRelationshipEdgeRepository)
  end

  it "uses redis repositories when redis is available and no backend is provided" do
    factory = described_class.new(backend: nil, redis: FakeRedis.new)

    expect(factory.interaction_events).to be_a(Harassment::Repositories::RedisInteractionEventRepository)
    expect(factory.classification_records).to be_a(Harassment::Repositories::RedisClassificationRecordRepository)
    expect(factory.classification_jobs).to be_a(Harassment::Repositories::RedisClassificationJobRepository)
    expect(factory.classification_cache).to be_a(Harassment::Repositories::RedisClassificationCacheRepository)
    expect(factory.server_rate_limits).to be_a(Harassment::Repositories::RedisServerRateLimitRepository)
    expect(factory.relationship_edges).to be_a(Harassment::Repositories::InMemoryRelationshipEdgeRepository)
  end

  it "returns Postgres repositories across the harassment runtime surface" do
    factory = described_class.new(backend: "postgres", connection: Object.new)

    expect(factory.interaction_events).to be_a(Harassment::Repositories::PostgresInteractionEventRepository)
    expect(factory.classification_records).to be_a(Harassment::Repositories::PostgresClassificationRecordRepository)
    expect(factory.classification_jobs).to be_a(Harassment::Repositories::PostgresClassificationJobRepository)
    expect(factory.classification_cache).to be_a(Harassment::Repositories::PostgresClassificationCacheRepository)
    expect(factory.server_rate_limits).to be_a(Harassment::Repositories::PostgresServerRateLimitRepository)
    expect(factory.relationship_edges).to be_a(Harassment::Repositories::PostgresRelationshipEdgeRepository)
  end
end
