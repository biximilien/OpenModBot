require "harassment/read_model"

describe Harassment::ReadModel do
  subject(:read_model) { described_class.new }

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

  it "ingests classified events into incidents and directed edges" do
    incident = read_model.ingest(event:, record:)

    expect(incident.intent).to eq("aggressive")
    expect(read_model.recent_incidents("789")).to eq([incident])

    edge = read_model.get_pair_relationship("321", "654")
    expect(edge.hostility_score).to eq(0.4)
    expect(edge.interaction_count).to eq(1)
    expect(edge.last_interaction_at).to eq(Time.utc(2026, 4, 25, 16, 0, 0))
  end

  it "aggregates user risk across outgoing edges" do
    read_model.ingest(event:, record:)
    second_event = Harassment::InteractionEvent.build(
      message_id: 124,
      server_id: 456,
      channel_id: 790,
      author_id: 321,
      target_user_ids: [999],
      raw_content: "second message",
    )
    second_record = Harassment::ClassificationRecord.build(
      message_id: 124,
      classifier_version: "harassment-v1",
      classification: { intent: "abusive", target_type: "individual" },
      severity_score: 0.5,
      confidence: 0.4,
    )

    read_model.ingest(event: second_event, record: second_record)

    expect(read_model.get_user_risk("321")).to be_within(0.0001).of(0.6)
  end
end
