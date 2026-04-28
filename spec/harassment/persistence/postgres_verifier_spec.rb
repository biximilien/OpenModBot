require "harassment/persistence/postgres_verifier"
require "harassment/repositories/postgres_classification_job_repository"
require "harassment/repositories/postgres_classification_record_repository"
require "harassment/repositories/postgres_interaction_event_repository"
require "harassment/repositories/postgres_relationship_edge_repository"
require "harassment/repositories/redis_classification_job_repository"
require "harassment/repositories/redis_classification_record_repository"
require "harassment/repositories/redis_interaction_event_repository"
require_relative "../../support/fake_postgres_connection"
require_relative "../../support/fake_redis"

describe Harassment::PostgresVerifier do
  subject(:verifier) { described_class.new(redis: redis, connection: connection) }

  let(:redis) { FakeRedis.new }
  let(:connection) { FakePostgresConnection.new }
  let(:source_interaction_events) { Harassment::Repositories::RedisInteractionEventRepository.new(redis: redis) }
  let(:source_classification_records) { Harassment::Repositories::RedisClassificationRecordRepository.new(redis: redis) }
  let(:source_classification_jobs) { Harassment::Repositories::RedisClassificationJobRepository.new(redis: redis) }
  let(:target_interaction_events) { Harassment::Repositories::PostgresInteractionEventRepository.new(connection: connection) }
  let(:target_classification_records) { Harassment::Repositories::PostgresClassificationRecordRepository.new(connection: connection) }
  let(:target_classification_jobs) { Harassment::Repositories::PostgresClassificationJobRepository.new(connection: connection) }
  let(:target_relationship_edges) { Harassment::Repositories::PostgresRelationshipEdgeRepository.new(connection: connection) }


  before do
    event = Harassment::InteractionEvent.build(
      message_id: 123,
      server_id: 456,
      channel_id: 789,
      author_id: 321,
      raw_content: "hello there",
    )
    record = Harassment::ClassificationRecord.build(
      server_id: 456,
      message_id: 123,
      classifier_version: "harassment-v1",
      model_version: "gpt-4o-2024-08-06",
      prompt_version: "harassment-prompt-v1",
      classification: { intent: "aggressive", target_type: "individual", toxicity_dimensions: {} },
      severity_score: 0.4,
      confidence: 0.8,
    )
    job = Harassment::ClassificationJob.build(
      server_id: 456,
      message_id: 123,
      classifier_version: "harassment-v1",
    )

    source_interaction_events.save(event)
    source_classification_records.save(record)
    source_classification_jobs.enqueue_unique(job)

    target_interaction_events.save(event)
    target_classification_records.save(record)
    target_classification_jobs.enqueue_unique(job)
    target_relationship_edges.save(
      Harassment::RelationshipEdge.build(
        server_id: 456,
        source_user_id: 321,
        target_user_id: 654,
        score_version: "harassment-score-v1",
        hostility_score: 0.4,
        interaction_count: 1,
        last_interaction_at: Time.utc(2026, 4, 25, 12, 0, 5),
      ),
    )
  end

  it "reports matching totals and per-server counts" do
    summary = verifier.run

    expect(summary[:interaction_events]).to eq(
      redis_total: 1,
      postgres_total: 1,
      redis_by_server: { "456" => 1 },
      postgres_by_server: { "456" => 1 },
      matches: true,
    )
    expect(summary[:classification_records][:matches]).to be(true)
    expect(summary[:classification_jobs][:matches]).to be(true)
    expect(summary[:relationship_edges]).to eq(
      total: 1,
      by_server: { "456" => 1 },
    )
    expect(summary[:spot_checks]).to eq(
      interaction_events: {
        sampled: 1,
        matched: 1,
        mismatches: [],
        matches: true,
      },
      classification_records: {
        sampled: 1,
        matched: 1,
        mismatches: [],
        matches: true,
      },
      classification_jobs: {
        sampled: 1,
        matched: 1,
        mismatches: [],
        matches: true,
      },
    )
  end

  it "reports mismatches when counts diverge" do
    target_classification_jobs.enqueue_unique(
      Harassment::ClassificationJob.build(
        server_id: 456,
        message_id: 999,
        classifier_version: "harassment-v1",
      ),
    )

    summary = verifier.run

    expect(summary[:classification_jobs][:redis_total]).to eq(1)
    expect(summary[:classification_jobs][:postgres_total]).to eq(2)
    expect(summary[:classification_jobs][:matches]).to be(false)
  end

  it "reports spot-check mismatches for missing migrated rows" do
    verifier_with_missing_record = described_class.new(
      redis: redis,
      connection: connection,
      classification_record_repository: double(find: nil),
    )

    summary = verifier_with_missing_record.run

    expect(summary[:spot_checks][:classification_records]).to eq(
      sampled: 1,
      matched: 0,
      mismatches: [
        {
          server_id: "456",
          message_id: "123",
          classifier_version: "harassment-v1",
          reason: "missing",
        },
      ],
      matches: false,
    )
  end

  it "limits spot checks to the requested sample size" do
    extra_event = Harassment::InteractionEvent.build(
      message_id: 124,
      server_id: 456,
      channel_id: 789,
      author_id: 654,
      raw_content: "another message",
    )
    source_interaction_events.save(extra_event)
    target_interaction_events.save(extra_event)

    summary = verifier.run(spot_check_limit: 1)

    expect(summary[:spot_checks][:interaction_events][:sampled]).to eq(1)
  end

  it "verifies specific known message ids when requested" do
    summary = verifier.run(verify_message_ids: [123])

    expect(summary[:known_message_ids]).to eq(
      "123" => {
        interaction_event: {
          found_in_redis: true,
          found_in_postgres: true,
          matches: true,
        },
        classification_records: {
          found_in_redis: true,
          found_in_postgres: true,
          matches: true,
          entries: [
            {
              found_in_redis: true,
              found_in_postgres: true,
              matches: true,
              identifier: {
                server_id: "456",
                classifier_version: "harassment-v1",
              },
            },
          ],
        },
        classification_jobs: {
          found_in_redis: true,
          found_in_postgres: true,
          matches: true,
          entries: [
            {
              found_in_redis: true,
              found_in_postgres: true,
              matches: true,
              identifier: {
                server_id: "456",
                classifier_version: "harassment-v1",
              },
            },
          ],
        },
      },
    )
  end

  it "reports known message ids that are missing from Redis" do
    summary = verifier.run(verify_message_ids: [999])

    expect(summary[:known_message_ids]["999"]).to eq(
      interaction_event: {
        found_in_redis: false,
        found_in_postgres: false,
        matches: false,
      },
      classification_records: {
        found_in_redis: false,
        found_in_postgres: false,
        matches: false,
        entries: [],
      },
      classification_jobs: {
        found_in_redis: false,
        found_in_postgres: false,
        matches: false,
        entries: [],
      },
    )
  end
end
