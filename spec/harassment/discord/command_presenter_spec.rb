require "harassment/discord/command_presenter"
require "harassment/incident/incident"
require "harassment/incident/recent_incidents_report"
require "harassment/risk/user_risk_report"

describe Harassment::Discord::CommandPresenter do
  subject(:presenter) { described_class.new }

  it "formats risk reports with sorted signal names" do
    report = Harassment::UserRiskReport.build(
      server_id: "123",
      user_id: "456",
      score_version: "harassment-score-v1",
      risk_score: 0.72,
      relationship_count: 2,
      signals: { persistence: 0.6, asymmetry: 0.8 },
    )

    expect(presenter.risk(report, user_id: "456")).to eq(
      "Harassment risk for <@456>\n" \
      "Score: 0.72\n" \
      "Score version: harassment-score-v1\n" \
      "Relationships: 2\n" \
      "Signals:\n" \
      "- Asymmetry: 0.80\n" \
      "- Persistence: 0.60",
    )
  end

  it "formats empty incidents reports with optional filters" do
    report = Harassment::RecentIncidentsReport.build(
      server_id: "123",
      channel_id: "321",
      user_id: "456",
      since: Time.utc(2026, 4, 25, 15, 0, 0),
      incidents: [],
    )

    expect(presenter.incidents(report, user_id: "456", window: "24h")).to eq(
      "No recent harassment incidents for <@456> in the last 24h in this channel",
    )
  end
end
