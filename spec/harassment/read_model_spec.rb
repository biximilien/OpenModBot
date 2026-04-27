require "harassment/risk/read_model"
require "harassment/risk/decay_policy"

describe Harassment::ReadModel do
  let(:decay_policy) { Harassment::DecayPolicy.new(lambda_value: Math.log(2) / 3600.0) }
  subject(:read_model) { described_class.new(decay_policy: decay_policy) }

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
      server_id: "456",
      message_id: 123,
      classifier_version: "harassment-v1",
      model_version: "gpt-4o-2024-08-06",
      prompt_version: "harassment-prompt-v1",
      classification: { intent: "aggressive", target_type: "individual" },
      severity_score: 0.8,
      confidence: 0.5,
      classified_at: Time.utc(2026, 4, 25, 16, 0, 0),
    )
  end

  it "ingests classified events into incidents and directed edges" do
    incident = read_model.ingest(event:, record:)

    expect(incident.intent).to eq("aggressive")
    expect(read_model.recent_incidents("456", "789")).to eq([incident])

    edge = read_model.get_pair_relationship("456", "321", "654", as_of: Time.utc(2026, 4, 25, 16, 0, 0))
    expect(edge.score_version).to eq("harassment-score-v1")
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
      server_id: "456",
      message_id: 124,
      classifier_version: "harassment-v1",
      model_version: "gpt-4o-2024-08-06",
      prompt_version: "harassment-prompt-v1",
      classification: { intent: "abusive", target_type: "individual" },
      severity_score: 0.5,
      confidence: 0.4,
      classified_at: Time.utc(2026, 4, 25, 16, 0, 0),
    )

    read_model.ingest(event: second_event, record: second_record)

    expect(read_model.get_user_risk("456", "321", as_of: second_record.classified_at)).to be_within(0.0001).of(0.6)
  end

  it "decays relationship scores over time on query" do
    read_model.ingest(event:, record:)

    edge = read_model.get_pair_relationship("456", "321", "654", as_of: Time.utc(2026, 4, 25, 17, 0, 0))

    expect(edge.hostility_score).to be_within(0.0001).of(0.2)
    expect(read_model.get_user_risk("456", "321", as_of: Time.utc(2026, 4, 25, 17, 0, 0))).to be_within(0.0001).of(0.2)
  end

  it "applies decay before adding new incident weight to an edge" do
    read_model.ingest(event:, record:)
    second_event = Harassment::InteractionEvent.build(
      message_id: 124,
      server_id: 456,
      channel_id: 789,
      author_id: 321,
      target_user_ids: [654],
      raw_content: "second message",
    )
    second_record = Harassment::ClassificationRecord.build(
      server_id: "456",
      message_id: 124,
      classifier_version: "harassment-v1",
      model_version: "gpt-4o-2024-08-06",
      prompt_version: "harassment-prompt-v1",
      classification: { intent: "abusive", target_type: "individual" },
      severity_score: 0.4,
      confidence: 0.5,
      classified_at: Time.utc(2026, 4, 25, 17, 0, 0),
    )

    read_model.ingest(event: second_event, record: second_record)

    edge = read_model.get_pair_relationship("456", "321", "654", as_of: Time.utc(2026, 4, 25, 17, 0, 0))
    expect(edge.hostility_score).to be_within(0.0001).of(0.4)
    expect(edge.interaction_count).to eq(2)
  end

  it "does not double count duplicate classifications for the same message and version" do
    first = read_model.ingest(event:, record:)
    second = read_model.ingest(event:, record:)

    expect(first).to eq(second)
    expect(read_model.recent_incidents("456", "789").length).to eq(1)
    expect(read_model.get_pair_relationship("456", "321", "654", as_of: record.classified_at).interaction_count).to eq(1)
    expect(read_model.get_user_risk("456", "321", as_of: record.classified_at)).to eq(0.4)
  end
end
