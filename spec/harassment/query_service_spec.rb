require "harassment/query_service"
require "harassment/decay_policy"
require "harassment/read_model"

describe Harassment::QueryService do
  subject(:query_service) { described_class.new(read_model: read_model) }

  let(:read_model) { Harassment::ReadModel.new(decay_policy: Harassment::DecayPolicy.new(lambda_value: Math.log(2) / 3600.0)) }
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

  before do
    read_model.ingest(event:, record:)
  end

  it "returns a structured user risk report" do
    report = query_service.get_user_risk("321", as_of: Time.utc(2026, 4, 25, 17, 0, 0))

    expect(report.user_id).to eq("321")
    expect(report.risk_score).to be_between(0.0, 1.0)
    expect(report.relationship_count).to eq(1)
    expect(report.signals.keys).to match_array(%i[asymmetry persistence burst_intensity target_concentration average_severity])
  end

  it "returns a structured pair relationship report" do
    report = query_service.get_pair_relationship("321", "654", as_of: Time.utc(2026, 4, 25, 17, 0, 0))

    expect(report.source_user_id).to eq("321")
    expect(report.target_user_id).to eq("654")
    expect(report.found?).to eq(true)
    expect(report.relationship_edge.interaction_count).to eq(1)
    expect(report.relationship_edge.hostility_score).to be_within(0.0001).of(0.2)
  end

  it "returns a structured recent incidents report" do
    report = query_service.recent_incidents("789")

    expect(report.channel_id).to eq("789")
    expect(report.user_id).to be_nil
    expect(report.since).to be_nil
    expect(report.incidents.length).to eq(1)
    expect(report.incidents.first.intent).to eq("aggressive")
  end

  it "filters recent incidents by user" do
    second_event = Harassment::InteractionEvent.build(
      message_id: 124,
      server_id: 456,
      channel_id: 789,
      author_id: 999,
      target_user_ids: [888],
      raw_content: "other incident",
    )
    second_record = Harassment::ClassificationRecord.build(
      message_id: 124,
      classifier_version: "harassment-v1",
      classification: { intent: "abusive", target_type: "individual" },
      severity_score: 0.5,
      confidence: 0.6,
      classified_at: Time.utc(2026, 4, 25, 16, 5, 0),
    )
    read_model.ingest(event: second_event, record: second_record)

    report = query_service.recent_incidents("789", user_id: "321")

    expect(report.user_id).to eq("321")
    expect(report.incidents.map(&:message_id)).to eq(["123"])
  end

  it "filters recent incidents by time window" do
    second_event = Harassment::InteractionEvent.build(
      message_id: 124,
      server_id: 456,
      channel_id: 789,
      author_id: 321,
      target_user_ids: [654],
      raw_content: "older incident",
    )
    second_record = Harassment::ClassificationRecord.build(
      message_id: 124,
      classifier_version: "harassment-v1",
      classification: { intent: "abusive", target_type: "individual" },
      severity_score: 0.5,
      confidence: 0.6,
      classified_at: Time.utc(2026, 4, 24, 12, 0, 0),
    )
    read_model.ingest(event: second_event, record: second_record)

    since = Time.utc(2026, 4, 25, 15, 0, 0)
    report = query_service.recent_incidents("789", since: since)

    expect(report.since).to eq(since)
    expect(report.incidents.map(&:message_id)).to eq(["123"])
  end
end
