require "harassment/interaction/event"

describe Harassment::InteractionEvent do
  it "builds a normalized interaction event" do
    timestamp = Time.utc(2026, 4, 25, 12, 0, 0)
    retention = Time.utc(2026, 5, 25, 12, 0, 0)

    event = described_class.build(
      message_id: 123,
      server_id: 456,
      channel_id: 789,
      author_id: 321,
      target_user_ids: [654, "654", 987],
      timestamp: timestamp,
      raw_content: "hello there",
      content_retention_expires_at: retention,
    )

    expect(event.message_id).to eq("123")
    expect(event.server_id).to eq("456")
    expect(event.channel_id).to eq("789")
    expect(event.author_id).to eq("321")
    expect(event.target_user_ids).to eq(%w[654 987])
    expect(event.timestamp).to eq(timestamp)
    expect(event.raw_content).to eq("hello there")
    expect(event.classification_status).to eq(Harassment::ClassificationStatus::PENDING)
    expect(event.content_retention_expires_at).to eq(retention)
    expect(event.content_redacted_at).to be_nil
  end

  it "supports updating classification status immutably" do
    event = described_class.build(
      message_id: 123,
      server_id: 456,
      channel_id: 789,
      author_id: 321,
      raw_content: "hello there",
    )

    updated = event.with_classification_status(Harassment::ClassificationStatus::CLASSIFIED)

    expect(updated.classification_status).to eq(Harassment::ClassificationStatus::CLASSIFIED)
    expect(event.classification_status).to eq(Harassment::ClassificationStatus::PENDING)
  end

  it "rejects unknown classification statuses" do
    expect do
      described_class.build(
        message_id: 123,
        server_id: 456,
        channel_id: 789,
        author_id: 321,
        raw_content: "hello there",
        classification_status: "mystery",
      )
    end.to raise_error(ArgumentError, "classification_status must be one of: pending, classified, failed_retryable, failed_terminal")
  end

  it "detects retention expiry and supports immutable redaction" do
    event = described_class.build(
      message_id: 123,
      server_id: 456,
      channel_id: 789,
      author_id: 321,
      raw_content: "hello there",
      content_retention_expires_at: Time.utc(2026, 4, 1, 12, 0, 0),
    )

    expect(event.retention_expired?(as_of: Time.utc(2026, 4, 2, 12, 0, 0))).to be(true)

    redacted = event.redact_content(redacted_at: Time.utc(2026, 4, 2, 12, 0, 0))

    expect(redacted.raw_content).to eq("[REDACTED]")
    expect(redacted.content_redacted_at).to eq(Time.utc(2026, 4, 2, 12, 0, 0))
    expect(event.content_redacted_at).to be_nil
  end
end
