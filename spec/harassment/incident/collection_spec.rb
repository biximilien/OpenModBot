require "harassment/incident/collection"
require "harassment/incident/incident"

describe Harassment::IncidentCollection do
  subject(:collection) { described_class.new([older_incident, newer_incident, other_channel_incident]) }

  let(:older_incident) do
    Harassment::Incident.new(
      message_id: "123",
      server_id: "456",
      channel_id: "789",
      author_id: "321",
      target_user_ids: ["654"],
      intent: "aggressive",
      target_type: "individual",
      severity_score: 0.8,
      confidence: 0.5,
      classified_at: Time.utc(2026, 4, 25, 16, 0, 0)
    )
  end

  let(:newer_incident) do
    Harassment::Incident.new(
      message_id: "124",
      server_id: "456",
      channel_id: "789",
      author_id: "999",
      target_user_ids: ["321"],
      intent: "abusive",
      target_type: "individual",
      severity_score: 0.5,
      confidence: 0.6,
      classified_at: Time.utc(2026, 4, 25, 16, 5, 0)
    )
  end

  let(:other_channel_incident) do
    older_incident.with(
      message_id: "125",
      channel_id: "790",
      classified_at: Time.utc(2026, 4, 25, 16, 10, 0)
    )
  end

  it "returns recent channel incidents newest first" do
    incidents = collection.recent(server_id: "456", channel_id: "789")

    expect(incidents.map(&:message_id)).to eq(%w[124 123])
  end

  it "filters recent incidents by involved user and lower time bound" do
    incidents = collection.recent(
      server_id: "456",
      channel_id: "789",
      user_id: "321",
      since: Time.utc(2026, 4, 25, 16, 1, 0)
    )

    expect(incidents.map(&:message_id)).to eq(["124"])
  end

  it "returns author incidents oldest first" do
    incidents = collection.for_author(server_id: "456", user_id: "321")

    expect(incidents.map(&:message_id)).to eq(%w[123 125])
  end
end
