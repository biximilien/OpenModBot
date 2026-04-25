require "harassment/user_risk_report"

describe Harassment::UserRiskReport do
  it "normalizes report values" do
    report = described_class.build(
      server_id: 456,
      user_id: 123,
      score_version: "harassment-score-v1",
      risk_score: 0.4,
      relationship_count: 2,
      signals: { asymmetry: 0.3 },
    )

    expect(report.server_id).to eq("456")
    expect(report.user_id).to eq("123")
    expect(report.score_version).to eq("harassment-score-v1")
    expect(report.risk_score).to eq(0.4)
    expect(report.relationship_count).to eq(2)
    expect(report.signals).to eq(asymmetry: 0.3)
  end
end
