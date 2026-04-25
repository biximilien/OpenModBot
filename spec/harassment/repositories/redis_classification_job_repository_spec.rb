require "harassment/repositories/redis_classification_job_repository"
require_relative "../../support/fake_redis"

describe Harassment::Repositories::RedisClassificationJobRepository do
  subject(:repository) { described_class.new(redis: redis) }

  let(:redis) { FakeRedis.new }
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

    expect(repository.due_jobs(as_of: Time.utc(2026, 4, 25, 15, 5, 0))).to eq([pending_job, retryable_job])
  end

  it "persists updates to job state" do
    repository.enqueue_unique(pending_job)
    updated = pending_job.with_status(Harassment::ClassificationStatus::CLASSIFIED, updated_at: Time.utc(2026, 4, 25, 15, 1, 0))

    repository.save(updated)

    expect(repository.find(server_id: "456", message_id: "123", classifier_version: "harassment-v1")).to eq(updated)
  end
end
