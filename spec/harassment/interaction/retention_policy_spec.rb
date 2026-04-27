require "harassment/interaction/retention_policy"

describe Harassment::RetentionPolicy do
  it "uses a 30-day default retention window" do
    policy = described_class.new
    timestamp = Time.utc(2026, 4, 1, 12, 0, 0)

    expect(policy.retention_expires_at(timestamp)).to eq(Time.utc(2026, 5, 1, 12, 0, 0))
  end

  it "determines whether an event is redactable" do
    event = Harassment::InteractionEvent.build(
      message_id: 123,
      server_id: 456,
      channel_id: 789,
      author_id: 321,
      raw_content: "hello there",
      content_retention_expires_at: Time.utc(2026, 4, 1, 12, 0, 0),
    )

    expect(described_class.new.redactable?(event, as_of: Time.utc(2026, 4, 2, 12, 0, 0))).to eq(true)
  end
end
