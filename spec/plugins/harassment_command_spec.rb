require "plugins/harassment_command"

describe ModerationGPT::Plugins::HarassmentCommand do
  let(:plugin) do
    instance_double(
      "HarassmentPlugin",
      get_user_risk: Harassment::UserRiskReport.build(
        user_id: "456",
        risk_score: 0.72,
        relationship_count: 2,
        signals: {
          asymmetry: 0.8,
          persistence: 0.6,
          burst_intensity: 0.4,
          target_concentration: 1.0,
          average_severity: 0.7,
        },
      ),
      get_pair_relationship: Harassment::PairRelationshipReport.build(
        source_user_id: "456",
        target_user_id: "789",
        relationship_edge: Harassment::RelationshipEdge.build(
          source_user_id: "456",
          target_user_id: "789",
          hostility_score: 0.5,
          interaction_count: 3,
          last_interaction_at: Time.utc(2026, 4, 25, 16, 0, 0),
        ),
      ),
      recent_incidents: Harassment::RecentIncidentsReport.build(
        channel_id: "321",
        incidents: [
          Harassment::Incident.new(
            message_id: "1",
            server_id: "123",
            channel_id: "321",
            author_id: "456",
            target_user_ids: ["789"],
            intent: "aggressive",
            target_type: "individual",
            severity_score: 0.8,
            confidence: 0.7,
            classified_at: Time.utc(2026, 4, 25, 16, 0, 0),
          ),
        ],
      ),
    )
  end

  subject(:command) { described_class.new(plugin) }

  let(:channel) { instance_double("Channel", id: 321) }
  let(:message) { instance_double("Message", content: "!moderation harassment risk <@456>") }
  let(:event) { instance_double("Event", message: message, channel: channel, respond: true) }

  it "matches risk commands" do
    message = instance_double("Message", content: "!moderation harassment risk <@456>")
    allow(event).to receive(:message).and_return(message)

    expect(command.matches?(event)).to eq(true)
  end

  it "responds with harassment risk details" do
    message = instance_double("Message", content: "!moderation harassment risk <@456>")
    allow(event).to receive(:message).and_return(message)

    command.handle(event)

    expect(event).to have_received(:respond).with(
      a_string_including(
        "Harassment risk for <@456>",
        "Score: 0.72",
        "Relationships: 2",
        "- Asymmetry: 0.80",
      ),
    )
  end

  it "responds with pair relationship details" do
    message = instance_double("Message", content: "!moderation harassment pair <@456> <@789>")
    allow(event).to receive(:message).and_return(message)

    command.handle(event)

    expect(event).to have_received(:respond).with(
      "Harassment relationship <@456> -> <@789>\nHostility: 0.50\nInteractions: 3\nLast seen: 2026-04-25T16:00:00Z",
    )
  end

  it "responds with recent incidents for the current channel" do
    message = instance_double("Message", content: "!moderation harassment incidents 1")
    allow(event).to receive(:message).and_return(message)

    command.handle(event)

    expect(plugin).to have_received(:recent_incidents).with(321, limit: 1)
    expect(event).to have_received(:respond).with(
      a_string_including("Recent harassment incidents:", "<@456> -> <@789> | aggressive | severity 0.80 | confidence 0.70"),
    )
  end
end
