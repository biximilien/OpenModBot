require "harassment/repositories/postgres_classification_cache_repository"
require_relative "../../support/fake_postgres_connection"

describe Harassment::Repositories::PostgresClassificationCacheRepository do
  subject(:repository) { described_class.new(connection: connection) }

  let(:connection) { FakePostgresConnection.new }
  let(:record) do
    Harassment::ClassificationRecord.build(
      server_id: 456,
      message_id: 123,
      classifier_version: "harassment-v1",
      model_version: "gpt-4o-2024-08-06",
      prompt_version: "harassment-prompt-v1",
      classification: { intent: "aggressive" },
      severity_score: 0.4,
      confidence: 0.8,
      classified_at: Time.utc(2026, 4, 25, 14, 0, 0),
    )
  end

  it "stores and retrieves unexpired cached records" do
    repository.store("cache-key", record, expires_at: Time.utc(2026, 4, 25, 15, 0, 0))

    expect(repository.fetch("cache-key", at: Time.utc(2026, 4, 25, 14, 30, 0))).to eq(record)
  end

  it "returns nil for expired cached records" do
    repository.store("cache-key", record, expires_at: Time.utc(2026, 4, 25, 15, 0, 0))

    expect(repository.fetch("cache-key", at: Time.utc(2026, 4, 25, 15, 0, 1))).to be_nil
  end
end
