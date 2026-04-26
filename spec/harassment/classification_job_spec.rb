require "harassment/classification_job"

describe Harassment::ClassificationJob do
  it "builds a normalized classification job" do
    now = Time.utc(2026, 4, 25, 15, 0, 0)

    job = described_class.build(
      server_id: 456,
      message_id: 123,
      classifier_version: "harassment-v1",
      enqueued_at: now,
      updated_at: now,
      available_at: now,
    )

    expect(job.message_id).to eq("123")
    expect(job.classifier_version).to eq(Harassment::ClassifierVersion.build("harassment-v1"))
    expect(job.status).to eq(Harassment::ClassificationStatus::PENDING)
    expect(job.attempt_count).to eq(0)
  end

  it "increments attempts immutably" do
    job = described_class.build(server_id: 456, message_id: 123, classifier_version: "harassment-v1")

    updated = job.increment_attempts

    expect(updated.attempt_count).to eq(1)
    expect(job.attempt_count).to eq(0)
  end

  it "requires server identity" do
    expect do
      described_class.build(message_id: 123, classifier_version: "harassment-v1")
    end.to raise_error(ArgumentError, /missing keyword: :server_id/)
  end
end
