require "harassment/recent_incidents_report"

describe Harassment::RecentIncidentsReport do
  it "normalizes the channel id and incidents" do
    report = described_class.build(channel_id: 789, incidents: [:incident], user_id: 123)

    expect(report.channel_id).to eq("789")
    expect(report.user_id).to eq("123")
    expect(report.incidents).to eq([:incident])
  end
end
