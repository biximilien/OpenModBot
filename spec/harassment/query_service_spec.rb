require "harassment/query_service"
require "harassment/read_model"

describe Harassment::QueryService do
  subject(:query_service) { described_class.new(read_model: read_model) }

  let(:read_model) { Harassment::ReadModel.new }
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
    report = query_service.get_user_risk("321")

    expect(report.user_id).to eq("321")
    expect(report.risk_score).to eq(0.4)
    expect(report.relationship_count).to eq(1)
  end

  it "returns a structured pair relationship report" do
    report = query_service.get_pair_relationship("321", "654")

    expect(report.source_user_id).to eq("321")
    expect(report.target_user_id).to eq("654")
    expect(report.found?).to eq(true)
    expect(report.relationship_edge.interaction_count).to eq(1)
  end

  it "returns a structured recent incidents report" do
    report = query_service.recent_incidents("789")

    expect(report.channel_id).to eq("789")
    expect(report.incidents.length).to eq(1)
    expect(report.incidents.first.intent).to eq("aggressive")
  end
end
