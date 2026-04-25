require "harassment/user_risk_report"

describe Harassment::UserRiskReport do
  it "normalizes report values" do
    report = described_class.build(user_id: 123, risk_score: 0.4, relationship_count: 2)

    expect(report.user_id).to eq("123")
    expect(report.risk_score).to eq(0.4)
    expect(report.relationship_count).to eq(2)
  end
end
