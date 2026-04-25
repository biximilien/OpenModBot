require "harassment/repositories/postgres_interaction_event_repository"
require_relative "../../support/fake_postgres_connection"

describe Harassment::Repositories::PostgresInteractionEventRepository do
  subject(:repository) { described_class.new(connection: connection) }

  let(:connection) { FakePostgresConnection.new }
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

  it "supports recent retrieval and redaction queries" do
    repository.save(event)
    repository.save(
      Harassment::InteractionEvent.build(
        message_id: 124,
        server_id: 456,
        channel_id: 789,
        author_id: 654,
        target_user_ids: [321],
        timestamp: Time.utc(2026, 4, 25, 12, 5, 0),
        raw_content: "later message",
        content_retention_expires_at: Time.utc(2026, 4, 26, 12, 0, 0),
      ),
    )

    expect(
      repository.recent_in_channel(server_id: "456", channel_id: "789", before: Time.utc(2026, 4, 25, 12, 6, 0), limit: 5).map(&:message_id),
    ).to eq(%w[123 124])
    expect(
      repository.recent_between_participants(
        server_id: "456",
        participant_ids: %w[321 654],
        before: Time.utc(2026, 4, 25, 12, 6, 0),
        limit: 5,
      ).map(&:message_id),
    ).to eq(%w[123 124])
    expect(repository.list_by_classification_status(Harassment::ClassificationStatus::PENDING).map(&:message_id)).to eq(%w[123 124])
    expect(repository.list_with_expired_content(as_of: Time.utc(2026, 4, 27, 12, 0, 0)).map(&:message_id)).to eq(["124"])

    redacted = repository.redact_content("124", redacted_at: Time.utc(2026, 4, 27, 12, 0, 0))
    expect(redacted.raw_content).to eq("[REDACTED]")
  end
end
