require "harassment/interaction/retention_manager"
require "harassment/repositories/in_memory_interaction_event_repository"

describe Harassment::RetentionManager do
  let(:interaction_events) { Harassment::Repositories::InMemoryInteractionEventRepository.new }

  subject(:manager) { described_class.new(interaction_events: interaction_events) }

  it "redacts expired event content while preserving metadata" do
    event = Harassment::InteractionEvent.build(
      message_id: 123,
      server_id: 456,
      channel_id: 789,
      author_id: 321,
      target_user_ids: [654],
      raw_content: "hello there",
      content_retention_expires_at: Time.utc(2026, 4, 1, 12, 0, 0),
    )
    interaction_events.save(event)

    redacted_events = manager.redact_expired_content(as_of: Time.utc(2026, 4, 2, 12, 0, 0))
    redacted_event = interaction_events.find("123", server_id: "456")

    expect(redacted_events).to eq([redacted_event])
    expect(redacted_event.raw_content).to eq("[REDACTED]")
    expect(redacted_event.content_redacted_at).to eq(Time.utc(2026, 4, 2, 12, 0, 0))
    expect(redacted_event.target_user_ids).to eq(["654"])
    expect(redacted_event.server_id).to eq("456")
  end

  it "does not redact unexpired or already-redacted events" do
    unexpired = Harassment::InteractionEvent.build(
      message_id: 123,
      server_id: 456,
      channel_id: 789,
      author_id: 321,
      raw_content: "hello there",
      content_retention_expires_at: Time.utc(2026, 4, 10, 12, 0, 0),
    )
    redacted = Harassment::InteractionEvent.build(
      message_id: 124,
      server_id: 456,
      channel_id: 789,
      author_id: 321,
      raw_content: "[REDACTED]",
      content_retention_expires_at: Time.utc(2026, 4, 1, 12, 0, 0),
      content_redacted_at: Time.utc(2026, 4, 2, 10, 0, 0),
    )

    interaction_events.save(unexpired)
    interaction_events.save(redacted)

    expect(manager.redact_expired_content(as_of: Time.utc(2026, 4, 2, 12, 0, 0))).to eq([])
  end
end
