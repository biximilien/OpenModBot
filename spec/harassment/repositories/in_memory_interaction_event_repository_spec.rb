require "harassment/repositories/in_memory_interaction_event_repository"
require "set"

describe Harassment::Repositories::InMemoryInteractionEventRepository do
  subject(:repository) { described_class.new }

  let(:event) do
    Harassment::InteractionEvent.build(
      message_id: 123,
      server_id: 456,
      channel_id: 789,
      author_id: 321,
      timestamp: Time.utc(2026, 4, 25, 12, 0, 0),
      raw_content: "hello there",
    )
  end

  it "stores and retrieves interaction events by message id" do
    repository.save(event)

    expect(repository.find("123")).to eq(event)
  end

  it "rejects duplicate interaction events" do
    repository.save(event)

    expect { repository.save(event) }.to raise_error(ArgumentError, "interaction event already exists for message_id=123")
  end

  it "updates classification status immutably" do
    repository.save(event)

    updated = repository.update_classification_status("123", Harassment::ClassificationStatus::CLASSIFIED)

    expect(updated.classification_status).to eq(Harassment::ClassificationStatus::CLASSIFIED)
    expect(repository.find("123").classification_status).to eq(Harassment::ClassificationStatus::CLASSIFIED)
  end

  it "lists events by classification status" do
    repository.save(event)
    repository.save(
      Harassment::InteractionEvent.build(
        message_id: 124,
        server_id: 456,
        channel_id: 789,
        author_id: 654,
        raw_content: "follow-up",
        classification_status: Harassment::ClassificationStatus::FAILED_RETRYABLE,
      ),
    )

    expect(repository.list_by_classification_status(Harassment::ClassificationStatus::PENDING).map(&:message_id)).to eq(["123"])
    expect(repository.list_by_classification_status(Harassment::ClassificationStatus::FAILED_RETRYABLE).map(&:message_id)).to eq(["124"])
  end

  it "lists events with expired content and redacts them" do
    repository.save(
      Harassment::InteractionEvent.build(
        message_id: 123,
        server_id: 456,
        channel_id: 789,
        author_id: 321,
        raw_content: "hello there",
        content_retention_expires_at: Time.utc(2026, 4, 1, 12, 0, 0),
      ),
    )

    expect(repository.list_with_expired_content(as_of: Time.utc(2026, 4, 2, 12, 0, 0)).map(&:message_id)).to eq(["123"])

    redacted = repository.redact_content("123", redacted_at: Time.utc(2026, 4, 2, 12, 0, 0))

    expect(redacted.raw_content).to eq("[REDACTED]")
    expect(repository.find("123").content_redacted_at).to eq(Time.utc(2026, 4, 2, 12, 0, 0))
  end

  it "lists recent events in a channel before a cutoff" do
    repository.save(event)
    repository.save(
      Harassment::InteractionEvent.build(
        message_id: 124,
        server_id: 456,
        channel_id: 789,
        author_id: 654,
        timestamp: Time.utc(2026, 4, 25, 12, 5, 0),
        raw_content: "later message",
      ),
    )
    repository.save(
      Harassment::InteractionEvent.build(
        message_id: 125,
        server_id: 456,
        channel_id: 790,
        author_id: 654,
        timestamp: Time.utc(2026, 4, 25, 12, 6, 0),
        raw_content: "other channel",
      ),
    )

    results = repository.recent_in_channel(server_id: "456", channel_id: "789", before: Time.utc(2026, 4, 25, 12, 6, 0), limit: 2)

    expect(results.map(&:message_id)).to eq(%w[123 124])
  end

  it "lists recent events involving matching participants in the same server" do
    repository.save(event)
    repository.save(
      Harassment::InteractionEvent.build(
        message_id: 124,
        server_id: 456,
        channel_id: 790,
        author_id: 654,
        target_user_ids: [999],
        timestamp: Time.utc(2026, 4, 25, 12, 5, 0),
        raw_content: "same author",
      ),
    )
    repository.save(
      Harassment::InteractionEvent.build(
        message_id: 125,
        server_id: 999,
        channel_id: 790,
        author_id: 321,
        target_user_ids: [654],
        timestamp: Time.utc(2026, 4, 25, 12, 6, 0),
        raw_content: "wrong server",
      ),
    )

    results = repository.recent_between_participants(
      server_id: "456",
      participant_ids: %w[321 654],
      before: Time.utc(2026, 4, 25, 12, 7, 0),
      limit: 5,
    )

    expect(results.map(&:message_id)).to eq(%w[123 124])
  end
end
