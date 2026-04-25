require "harassment/incident"

describe Harassment::Incident do
  it "builds an incident from an interaction event and classification record" do
    event = Harassment::InteractionEvent.build(
      message_id: 123,
      server_id: 456,
      channel_id: 789,
      author_id: 321,
      target_user_ids: [654],
      raw_content: "hello there",
    )
    record = Harassment::ClassificationRecord.build(
      message_id: 123,
      classifier_version: "harassment-v1",
      classification: { intent: "aggressive", target_type: "individual" },
      severity_score: 0.8,
      confidence: 0.9,
    )

    incident = described_class.from_event_and_record(event:, record:)

    expect(incident.message_id).to eq("123")
    expect(incident.server_id).to eq("456")
    expect(incident.channel_id).to eq("789")
    expect(incident.author_id).to eq("321")
    expect(incident.target_user_ids).to eq(["654"])
    expect(incident.intent).to eq("aggressive")
    expect(incident.target_type).to eq("individual")
    expect(incident.severity_score).to eq(0.8)
    expect(incident.confidence).to eq(0.9)
  end
end
