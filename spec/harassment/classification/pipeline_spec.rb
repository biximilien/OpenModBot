require "harassment/classification/pipeline"
require "harassment/repositories/in_memory_interaction_event_repository"
require "harassment/repositories/in_memory_classification_record_repository"
require "harassment/repositories/in_memory_classification_job_repository"

describe Harassment::ClassificationPipeline do
  subject(:pipeline) do
    described_class.new(
      interaction_events: interaction_events,
      classification_records: classification_records,
      classification_jobs: classification_jobs
    )
  end

  let(:interaction_events) { Harassment::Repositories::InMemoryInteractionEventRepository.new }
  let(:classification_records) { Harassment::Repositories::InMemoryClassificationRecordRepository.new }
  let(:classification_jobs) { Harassment::Repositories::InMemoryClassificationJobRepository.new }

  let(:event) do
    Harassment::InteractionEvent.build(
      message_id: 123,
      server_id: 456,
      channel_id: 789,
      author_id: 321,
      raw_content: "hello there"
    )
  end

  before do
    interaction_events.save(event)
  end

  it "enqueues a unique classification job per message and classifier version" do
    first = pipeline.enqueue(message_id: "123", server_id: "456", classifier_version: "harassment-v1")
    second = pipeline.enqueue(message_id: "123", server_id: "456", classifier_version: "harassment-v1")

    expect(first).to eq(second)
    expect(classification_jobs.due_jobs.length).to eq(1)
  end

  it "records a successful classification idempotently" do
    pipeline.enqueue(message_id: "123", server_id: "456", classifier_version: "harassment-v1")
    record = Harassment::ClassificationRecord.build(
      server_id: "456",
      message_id: "123",
      classifier_version: "harassment-v1",
      model_version: "gpt-4o-2024-08-06",
      prompt_version: "harassment-prompt-v1",
      classification: { intent: "aggressive" },
      severity_score: 0.8,
      confidence: 0.9
    )

    first = pipeline.record_success(record)
    second = pipeline.record_success(record)

    expect(first).to eq(record)
    expect(second).to eq(record)
    expect(interaction_events.find("123", server_id: "456").classification_status).to eq(Harassment::ClassificationStatus::CLASSIFIED)
    expect(classification_jobs.find(server_id: "456", message_id: "123",
                                    classifier_version: "harassment-v1").status).to eq(Harassment::ClassificationStatus::CLASSIFIED)
  end

  it "records retryable failures with attempt tracking" do
    retry_at = Time.utc(2026, 4, 25, 15, 10, 0)
    pipeline.enqueue(message_id: "123", server_id: "456", classifier_version: "harassment-v1")

    job = pipeline.record_retryable_failure(
      server_id: "456",
      message_id: "123",
      classifier_version: "harassment-v1",
      error: StandardError.new("temporary failure"),
      retry_at: retry_at
    )

    expect(job.status).to eq(Harassment::ClassificationStatus::FAILED_RETRYABLE)
    expect(job.attempt_count).to eq(1)
    expect(job.available_at).to eq(retry_at)
    expect(interaction_events.find("123", server_id: "456").classification_status).to eq(Harassment::ClassificationStatus::FAILED_RETRYABLE)
  end

  it "records terminal failures" do
    pipeline.enqueue(message_id: "123", server_id: "456", classifier_version: "harassment-v1")

    job = pipeline.record_terminal_failure(
      server_id: "456",
      message_id: "123",
      classifier_version: "harassment-v1",
      error: StandardError.new("permanent failure")
    )

    expect(job.status).to eq(Harassment::ClassificationStatus::FAILED_TERMINAL)
    expect(job.attempt_count).to eq(1)
    expect(interaction_events.find("123", server_id: "456").classification_status).to eq(Harassment::ClassificationStatus::FAILED_TERMINAL)
  end

  it "defers jobs without consuming an attempt" do
    pipeline.enqueue(message_id: "123", server_id: "456", classifier_version: "harassment-v1")

    job = pipeline.defer_job(
      server_id: "456",
      message_id: "123",
      classifier_version: "harassment-v1",
      available_at: Time.utc(2026, 4, 25, 15, 10, 0)
    )

    expect(job.status).to eq(Harassment::ClassificationStatus::PENDING)
    expect(job.attempt_count).to eq(0)
    expect(job.available_at).to eq(Time.utc(2026, 4, 25, 15, 10, 0))
    expect(interaction_events.find("123", server_id: "456").classification_status).to eq(Harassment::ClassificationStatus::PENDING)
  end
end
