require "harassment/repositories/in_memory_classification_job_repository"

describe Harassment::Repositories::InMemoryClassificationJobRepository do
  subject(:repository) { described_class.new }

  let(:pending_job) do
    Harassment::ClassificationJob.build(
      server_id: 456,
      message_id: 123,
      classifier_version: "harassment-v1",
      available_at: Time.utc(2026, 4, 25, 15, 0, 0),
    )
  end

  let(:retryable_job) do
    Harassment::ClassificationJob.build(
      server_id: 456,
      message_id: 124,
      classifier_version: "harassment-v1",
      status: Harassment::ClassificationStatus::FAILED_RETRYABLE,
      available_at: Time.utc(2026, 4, 25, 15, 5, 0),
    )
  end

  it "enqueues jobs uniquely by message and classifier version" do
    first = repository.enqueue_unique(pending_job)
    second = repository.enqueue_unique(pending_job)

    expect(first).to eq(second)
    expect(repository.find(server_id: "456", message_id: "123", classifier_version: "harassment-v1")).to eq(pending_job)
  end

  it "returns due pending and retryable jobs" do
    repository.enqueue_unique(pending_job)
    repository.enqueue_unique(retryable_job)

    due_jobs = repository.due_jobs(as_of: Time.utc(2026, 4, 25, 15, 5, 0))

    expect(due_jobs).to eq([pending_job, retryable_job])
  end

  it "does not return classified or terminal jobs as due" do
    repository.enqueue_unique(
      Harassment::ClassificationJob.build(
        server_id: 456,
        message_id: 125,
        classifier_version: "harassment-v1",
        status: Harassment::ClassificationStatus::CLASSIFIED,
      ),
    )
    repository.enqueue_unique(
      Harassment::ClassificationJob.build(
        server_id: 456,
        message_id: 126,
        classifier_version: "harassment-v1",
        status: Harassment::ClassificationStatus::FAILED_TERMINAL,
      ),
    )

    expect(repository.due_jobs).to eq([])
  end
end
