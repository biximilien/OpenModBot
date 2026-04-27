require "harassment/interaction/message_ingestor"
require "harassment/repositories/in_memory_classification_job_repository"
require "harassment/repositories/in_memory_classification_record_repository"
require "harassment/repositories/in_memory_interaction_event_repository"

describe Harassment::MessageIngestor do
  let(:interaction_events) { Harassment::Repositories::InMemoryInteractionEventRepository.new }
  let(:classification_records) { Harassment::Repositories::InMemoryClassificationRecordRepository.new }
  let(:classification_jobs) { Harassment::Repositories::InMemoryClassificationJobRepository.new }
  let(:classification_pipeline) do
    Harassment::ClassificationPipeline.new(
      interaction_events: interaction_events,
      classification_records: classification_records,
      classification_jobs: classification_jobs,
    )
  end

  subject(:ingestor) do
    described_class.new(
      interaction_events: interaction_events,
      classification_pipeline: classification_pipeline,
      classifier_version: "harassment-v1",
    )
  end

  let(:mentioned_user) { instance_double("User", id: 654) }
  let(:message) do
    instance_double(
      "Message",
      id: 123,
      content: "hello there",
      timestamp: Time.utc(2026, 4, 25, 17, 0, 0),
      mentions: [mentioned_user],
    )
  end
  let(:server) { instance_double("Server", id: 456) }
  let(:channel) { instance_double("Channel", id: 789) }
  let(:user) { instance_double("User", id: 321) }
  let(:event) { instance_double("Event", message: message, server: server, channel: channel, user: user) }

  it "creates an interaction event and enqueues classification" do
    interaction_event = ingestor.ingest(event)

    expect(interaction_event.message_id).to eq("123")
    expect(interaction_event.target_user_ids).to eq(["654"])
    expect(interaction_event.content_retention_expires_at).to eq(Time.utc(2026, 5, 25, 17, 0, 0))

    job = classification_jobs.find(server_id: "456", message_id: "123", classifier_version: "harassment-v1")
    expect(job).not_to be_nil
    expect(job.status).to eq(Harassment::ClassificationStatus::PENDING)
  end

  it "is idempotent for duplicate ingestion attempts" do
    first = ingestor.ingest(event)
    second = ingestor.ingest(event)

    expect(first).to eq(second)
    expect(classification_jobs.due_jobs.length).to eq(1)
  end
end
