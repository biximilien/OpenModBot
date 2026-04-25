require "plugins/harassment_plugin"

describe ModerationGPT::Plugins::HarassmentPlugin do
  subject(:plugin) { described_class.new }

  let(:event) do
    Harassment::InteractionEvent.build(
      message_id: 123,
      server_id: 456,
      channel_id: 789,
      author_id: 321,
      target_user_ids: [654],
      raw_content: "hello there",
    )
  end

  let(:record) do
    Harassment::ClassificationRecord.build(
      message_id: 123,
      classifier_version: "harassment-v1",
      classification: { intent: "aggressive", target_type: "individual" },
      severity_score: 0.8,
      confidence: 0.5,
      classified_at: Time.utc(2026, 4, 25, 16, 0, 0),
    )
  end

  it "records classified events in its read model" do
    incident = plugin.record_classification(event:, record:)

    expect(incident.intent).to eq("aggressive")
    expect(plugin.recent_incidents("789")).to eq([incident])
  end

  it "exposes user risk and pair relationships" do
    plugin.record_classification(event:, record:)

    expect(plugin.get_user_risk("321")).to eq(0.4)
    expect(plugin.get_pair_relationship("321", "654").interaction_count).to eq(1)
  end
end
