require "harassment/incident/recent_incidents_report"

describe Harassment::RecentIncidentsReport do
  it "normalizes the channel id and incidents" do
    since = Time.utc(2026, 4, 25, 12, 0, 0)
    report = described_class.build(server_id: 456, channel_id: 789, incidents: [:incident], user_id: 123, since: since)

    expect(report.server_id).to eq("456")
    expect(report.channel_id).to eq("789")
    expect(report.user_id).to eq("123")
    expect(report.since).to eq(since)
    expect(report.incidents).to eq([:incident])
  end
end
