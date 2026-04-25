require "harassment/classification_worker"
require "harassment/classification_pipeline"
require "harassment/repositories/in_memory_classification_job_repository"
require "harassment/repositories/in_memory_classification_record_repository"
require "harassment/repositories/in_memory_interaction_event_repository"

describe Harassment::ClassificationWorker do
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
  let(:classifier) { instance_double("Classifier") }
  let(:context_assembler) { instance_double("ContextAssembler") }
  let(:event) do
    Harassment::InteractionEvent.build(
      message_id: 123,
      server_id: 456,
      channel_id: 789,
      author_id: 321,
      target_user_ids: [654],
      timestamp: Time.utc(2026, 4, 25, 18, 0, 0),
      raw_content: "you're not welcome here",
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
      confidence: 0.9,
      classified_at: Time.utc(2026, 4, 25, 18, 1, 0),
    )
  end
  let(:processed) { [] }

  subject(:worker) do
    described_class.new(
      interaction_events: interaction_events,
      classification_jobs: classification_jobs,
      classification_pipeline: classification_pipeline,
      classifier: classifier,
      context_assembler: context_assembler,
      on_success: ->(event:, record:) { processed << [event, record] },
    )
  end

  before do
    interaction_events.save(event)
    classification_pipeline.enqueue(message_id: "123", classifier_version: "harassment-v1", enqueued_at: event.timestamp)
    allow(context_assembler).to receive(:build_for).and_return({ recent_channel_messages: [], recent_pair_interactions: [], participant_labels: {} })
  end

  it "processes due jobs and records successful classifications" do
    allow(classifier).to receive(:classify).and_return(record)

    results = worker.process_due_jobs(as_of: Time.utc(2026, 4, 25, 18, 1, 0))

    expect(results).to eq([record])
    expect(classifier).to have_received(:classify).with(
      event: event,
      classifier_version: Harassment::ClassifierVersion.build("harassment-v1"),
      context: { recent_channel_messages: [], recent_pair_interactions: [], participant_labels: {} },
      classified_at: Time.utc(2026, 4, 25, 18, 1, 0),
    )
    expect(classification_records.latest_for_message(server_id: "456", message_id: "123")).to eq(record)
    expect(classification_jobs.find(server_id: "456", message_id: "123", classifier_version: "harassment-v1").status).to eq(Harassment::ClassificationStatus::CLASSIFIED)
    expect(processed).to eq([[event, record]])
  end

  it "records retryable failures with backoff" do
    allow(classifier).to receive(:classify).and_raise(StandardError, "temporary failure")

    worker.process_due_jobs(as_of: Time.utc(2026, 4, 25, 18, 1, 0))

    job = classification_jobs.find(server_id: "456", message_id: "123", classifier_version: "harassment-v1")
    expect(job.status).to eq(Harassment::ClassificationStatus::FAILED_RETRYABLE)
    expect(job.attempt_count).to eq(1)
    expect(job.available_at).to eq(Time.utc(2026, 4, 25, 18, 2, 0))
  end

  it "records terminal failures for non-retryable classifier errors" do
    allow(classifier).to receive(:classify).and_raise(ArgumentError, "invalid schema output")

    worker.process_due_jobs(as_of: Time.utc(2026, 4, 25, 18, 1, 0))

    job = classification_jobs.find(server_id: "456", message_id: "123", classifier_version: "harassment-v1")
    expect(job.status).to eq(Harassment::ClassificationStatus::FAILED_TERMINAL)
    expect(job.attempt_count).to eq(1)
  end

  it "stops retrying once max attempts are exhausted" do
    allow(classifier).to receive(:classify).and_raise(StandardError, "temporary failure")

    worker.process_due_jobs(as_of: Time.utc(2026, 4, 25, 18, 1, 0))
    worker.process_due_jobs(as_of: Time.utc(2026, 4, 25, 18, 6, 0))
    worker.process_due_jobs(as_of: Time.utc(2026, 4, 25, 18, 36, 0))

    job = classification_jobs.find(server_id: "456", message_id: "123", classifier_version: "harassment-v1")
    expect(job.status).to eq(Harassment::ClassificationStatus::FAILED_TERMINAL)
    expect(job.attempt_count).to eq(3)
  end
end
