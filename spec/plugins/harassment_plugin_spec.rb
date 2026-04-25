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
    expect(plugin.recent_incidents("789").incidents).to eq([incident])
  end

  it "exposes user risk and pair relationships" do
    plugin.record_classification(event:, record:)

    risk_report = plugin.get_user_risk("321", as_of: record.classified_at)

    expect(risk_report.risk_score).to be_between(0.0, 1.0)
    expect(risk_report.signals.keys).to match_array(%i[asymmetry persistence burst_intensity target_concentration average_severity])
    expect(plugin.get_pair_relationship("321", "654", as_of: record.classified_at).relationship_edge.interaction_count).to eq(1)
  end

  it "is idempotent for duplicate classification deliveries" do
    first = plugin.record_classification(event:, record:)
    second = plugin.record_classification(event:, record:)

    expect(first).to eq(second)
    expect(plugin.recent_incidents("789").incidents.length).to eq(1)
    expect(plugin.get_pair_relationship("321", "654").relationship_edge.interaction_count).to eq(1)
  end

  it "exposes a harassment moderation command" do
    expect(plugin.commands.length).to eq(1)
    expect(plugin.commands.first.help_lines).to include("!moderation harassment risk @user")
  end
end
