require "harassment/persistence/postgres_bootstrap"
require "harassment/repositories/postgres_classification_job_repository"
require "harassment/repositories/postgres_classification_record_repository"
require "harassment/repositories/postgres_interaction_event_repository"
require "harassment/repositories/redis_classification_job_repository"
require "harassment/repositories/redis_classification_record_repository"
require "harassment/repositories/redis_interaction_event_repository"
require_relative "../../support/fake_postgres_connection"
require_relative "../../support/fake_redis"

describe Harassment::PostgresBootstrap do
  subject(:bootstrap) do
    described_class.new(
      redis: redis,
      interaction_events: target_interaction_events,
      classification_records: target_classification_records,
      classification_jobs: target_classification_jobs
    )
  end

  let(:redis) { FakeRedis.new }
  let(:connection) { FakePostgresConnection.new }
  let(:source_interaction_events) { Harassment::Repositories::RedisInteractionEventRepository.new(redis: redis) }
  let(:source_classification_records) { Harassment::Repositories::RedisClassificationRecordRepository.new(redis: redis) }
  let(:source_classification_jobs) { Harassment::Repositories::RedisClassificationJobRepository.new(redis: redis) }
  let(:target_interaction_events) { Harassment::Repositories::PostgresInteractionEventRepository.new(connection: connection) }
  let(:target_classification_records) { Harassment::Repositories::PostgresClassificationRecordRepository.new(connection: connection) }
  let(:target_classification_jobs) { Harassment::Repositories::PostgresClassificationJobRepository.new(connection: connection) }

  let(:event) do
    Harassment::InteractionEvent.build(
      message_id: 123,
      server_id: 456,
      channel_id: 789,
      author_id: 321,
      target_user_ids: [654],
      timestamp: Time.utc(2026, 4, 25, 12, 0, 0),
      raw_content: "hello there"
    )
  end
  let(:record) do
    Harassment::ClassificationRecord.build(
      server_id: 456,
      message_id: 123,
      classifier_version: "harassment-v1",
      model_version: "gpt-4o-2024-08-06",
      prompt_version: "harassment-prompt-v1",
      classification: { intent: "aggressive", target_type: "individual", toxicity_dimensions: {} },
      severity_score: 0.4,
      confidence: 0.8,
      classified_at: Time.utc(2026, 4, 25, 12, 0, 5)
    )
  end
  let(:job) do
    Harassment::ClassificationJob.build(
      server_id: 456,
      message_id: 123,
      classifier_version: "harassment-v1",
      available_at: Time.utc(2026, 4, 25, 12, 0, 0),
      enqueued_at: Time.utc(2026, 4, 25, 12, 0, 0),
      updated_at: Time.utc(2026, 4, 25, 12, 0, 0)
    )
  end

  before do
    source_interaction_events.save(event)
    source_classification_records.save(record)
    source_classification_jobs.enqueue_unique(job)
  end

  it "copies harassment pipeline state from Redis into Postgres repositories" do
    summary = bootstrap.run

    expect(summary).to eq(
      interaction_events: { imported: 1, skipped: 0 },
      classification_records: { imported: 1, skipped: 0 },
      classification_jobs: { imported: 1, skipped: 0 }
    )
    expect(target_interaction_events.find("123", server_id: "456")).to eq(event)
    expect(target_classification_records.find(server_id: "456", message_id: "123",
                                              classifier_version: "harassment-v1")).to eq(record)
    expect(target_classification_jobs.find(server_id: "456", message_id: "123",
                                           classifier_version: "harassment-v1")).to eq(job)
  end

  it "is idempotent on repeated bootstrap runs" do
    bootstrap.run
    summary = bootstrap.run

    expect(summary).to eq(
      interaction_events: { imported: 0, skipped: 1 },
      classification_records: { imported: 0, skipped: 1 },
      classification_jobs: { imported: 0, skipped: 1 }
    )
  end
end
