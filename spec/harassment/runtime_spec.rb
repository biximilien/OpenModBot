require "harassment/runtime"
require_relative "../support/fake_redis"
require_relative "../support/fake_postgres_connection"

describe Harassment::Runtime do
  let(:client) { instance_double("OpenAIClient") }
  let(:classifier) { instance_double("Classifier", cache_identity: { classifier_class: "RuntimeClassifier" }) }
  let(:recorded) { [] }
  let(:redis) { nil }
  let(:connection) { nil }
  let(:mentioned_user) { instance_double("User", id: 654) }
  let(:message) do
    instance_double(
      "Message",
      id: 123,
      content: "hello there",
      timestamp: Time.utc(2026, 4, 25, 16, 0, 0),
      mentions: [mentioned_user],
    )
  end
  let(:server) { instance_double("Server", id: 456) }
  let(:channel) { instance_double("Channel", id: 789) }
  let(:user) { instance_double("User", id: 321) }
  let(:event) { instance_double("Event", message: message, server: server, channel: channel, user: user) }

  subject(:runtime) do
    described_class.new(
      redis: redis,
      connection: connection,
      classifier_version: "harassment-v1",
      classifier: classifier,
      on_classification: ->(event:, record:) { recorded << [event, record] },
    )
  end

  let(:record) do
    Harassment::ClassificationRecord.build(
      server_id: "456",
      message_id: "123",
      classifier_version: "harassment-v1",
      classification: {
        intent: "aggressive",
        target_type: "individual",
        toxicity_dimensions: {
          insult: true,
          threat: false,
          profanity: false,
          exclusion: true,
          harassment: true,
        },
      },
      severity_score: 0.8,
      confidence: 0.5,
      classified_at: Time.utc(2026, 4, 25, 16, 1, 0),
    )
  end

  it "ingests Discord messages into interaction events and pending jobs" do
    interaction_event = runtime.ingest_message(event)

    expect(interaction_event.message_id).to eq("123")
    expect(runtime.classification_jobs.due_jobs.length).to eq(1)
  end

  it "processes queued classifications and emits the stored record to consumers" do
    runtime.ingest_message(event)
    allow(classifier).to receive(:classify).and_return(record)

    results = runtime.process_due_classifications(as_of: Time.utc(2026, 4, 25, 16, 1, 0))

    expect(results).to eq([record])
    expect(recorded.length).to eq(1)
    expect(recorded.first.last).to eq(record)
    expect(recorded.first.first).to be_a(Harassment::InteractionEvent)
    expect(recorded.first.first.classification_status).to eq(Harassment::ClassificationStatus::PENDING)
    expect(runtime.interaction_events.find("123").classification_status).to eq(Harassment::ClassificationStatus::CLASSIFIED)
    expect(runtime.classification_records.latest_for_message(server_id: "456", message_id: "123")).to eq(record)
  end

  context "with Redis-backed repositories" do
    let(:redis) { FakeRedis.new }

    it "persists runtime data across instances that share Redis" do
      runtime.ingest_message(event)
      allow(classifier).to receive(:classify).and_return(record)
      runtime.process_due_classifications(as_of: Time.utc(2026, 4, 25, 16, 1, 0))

      second_runtime = described_class.new(redis: redis, classifier_version: "harassment-v1", classifier: classifier)

      expect(second_runtime.interaction_events.find("123")&.classification_status).to eq(Harassment::ClassificationStatus::CLASSIFIED)
      expect(second_runtime.classification_records.latest_for_message(server_id: "456", message_id: "123")).to eq(record)
      expect(second_runtime.classification_jobs.find(server_id: "456", message_id: "123", classifier_version: "harassment-v1")&.status).to eq(Harassment::ClassificationStatus::CLASSIFIED)
    end
  end

  context "with Postgres core repositories and Redis operational repositories" do
    let(:redis) { FakeRedis.new }
    let(:connection) { FakePostgresConnection.new }

    subject(:runtime) do
      described_class.new(
        redis: redis,
        connection: connection,
        storage_backend: "postgres",
        classifier_version: "harassment-v1",
        classifier: classifier,
        on_classification: ->(event:, record:) { recorded << [event, record] },
      )
    end

    it "uses Postgres for durable classification state while keeping runtime processing intact" do
      runtime.ingest_message(event)
      allow(classifier).to receive(:classify).and_return(record)

      results = runtime.process_due_classifications(as_of: Time.utc(2026, 4, 25, 16, 1, 0))

      expect(results).to eq([record])
      expect(runtime.interaction_events).to be_a(Harassment::Repositories::PostgresInteractionEventRepository)
      expect(runtime.classification_records).to be_a(Harassment::Repositories::PostgresClassificationRecordRepository)
      expect(runtime.classification_jobs).to be_a(Harassment::Repositories::PostgresClassificationJobRepository)
      expect(runtime.classification_records.latest_for_message(server_id: "456", message_id: "123")).to eq(record)
      expect(runtime.classification_jobs.find(server_id: "456", message_id: "123", classifier_version: "harassment-v1")&.status).to eq(Harassment::ClassificationStatus::CLASSIFIED)
    end
  end
end
