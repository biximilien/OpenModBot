require "plugins/harassment_command"
require "harassment/incident/incident"
require "harassment/relationship/pair_relationship_report"
require "harassment/incident/recent_incidents_report"
require "harassment/relationship/edge"
require "harassment/risk/user_risk_report"

describe ModerationGPT::Plugins::HarassmentCommand do
  subject(:command) { described_class.new(query_service) }

  let(:query_service) do
    instance_double(
      "Harassment::QueryService",
      get_user_risk: Harassment::UserRiskReport.build(
        server_id: "123",
        user_id: "456",
        score_version: "harassment-score-v1",
        risk_score: 0.72,
        relationship_count: 2,
        signals: {
          asymmetry: 0.8,
          persistence: 0.6,
          burst_intensity: 0.4,
          target_concentration: 1.0,
          average_severity: 0.7
        }
      ),
      get_pair_relationship: Harassment::PairRelationshipReport.build(
        server_id: "123",
        source_user_id: "456",
        target_user_id: "789",
        relationship_edge: Harassment::RelationshipEdge.build(
          server_id: "123",
          source_user_id: "456",
          target_user_id: "789",
          score_version: "harassment-score-v1",
          hostility_score: 0.5,
          interaction_count: 3,
          last_interaction_at: Time.utc(2026, 4, 25, 16, 0, 0)
        )
      ),
      recent_incidents: Harassment::RecentIncidentsReport.build(
        server_id: "123",
        channel_id: "321",
        user_id: nil,
        since: nil,
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
            classified_at: Time.utc(2026, 4, 25, 16, 0, 0)
          )
        ]
      )
    )
  end

  let(:channel) { instance_double("Channel", id: 321) }
  let(:server) { instance_double("Server", id: 123) }
  let(:message) { instance_double("Message", content: "!moderation harassment risk <@456>") }
  let(:event) { instance_double("Event", message: message, server: server, channel: channel, respond: true) }

  it "matches risk commands" do
    message = instance_double("Message", content: "!moderation harassment risk <@456>")
    allow(event).to receive(:message).and_return(message)

    expect(command.matches?(event)).to be(true)
  end

  it "responds with harassment risk details" do
    message = instance_double("Message", content: "!moderation harassment risk <@456>")
    allow(event).to receive(:message).and_return(message)

    command.handle(event)

    expect(event).to have_received(:respond).with(
      a_string_including(
        "Harassment risk for <@456>",
        "Score: 0.72",
        "Score version: harassment-score-v1",
        "Relationships: 2",
        "- Asymmetry: 0.80"
      )
    )
  end

  it "responds with pair relationship details" do
    message = instance_double("Message", content: "!moderation harassment pair <@456> <@789>")
    allow(event).to receive(:message).and_return(message)

    command.handle(event)

    expect(event).to have_received(:respond).with(
      "Harassment relationship <@456> -> <@789>\n" \
      "Hostility: 0.50\n" \
      "Score version: harassment-score-v1\n" \
      "Interactions: 3\n" \
      "Last seen: 2026-04-25T16:00:00Z"
    )
  end

  it "responds with recent incidents for the current channel" do
    message = instance_double("Message", content: "!moderation harassment incidents 1")
    allow(event).to receive(:message).and_return(message)

    command.handle(event)

    expect(query_service).to have_received(:recent_incidents).with(123, 321, limit: 1, user_id: nil, since: nil)
    expect(event).to have_received(:respond).with(
      a_string_including(
        "Recent harassment incidents:",
        "<@456> -> <@789> | aggressive | severity 0.80 | confidence 0.70"
      )
    )
  end

  it "responds with filtered incidents for a specific user" do
    filtered_report = Harassment::RecentIncidentsReport.build(
      server_id: "123",
      channel_id: "321",
      user_id: "456",
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
          classified_at: Time.utc(2026, 4, 25, 16, 0, 0)
        )
      ]
    )
    allow(query_service).to receive(:recent_incidents).and_return(filtered_report)
    message = instance_double("Message", content: "!moderation harassment incidents <@456> 1")
    allow(event).to receive(:message).and_return(message)

    command.handle(event)

    expect(query_service).to have_received(:recent_incidents).with(123, 321, limit: 1, user_id: "456", since: nil)
    expect(event).to have_received(:respond).with(
      a_string_including("Recent harassment incidents for <@456>:")
    )
  end

  it "responds with a filtered empty-state message" do
    allow(query_service).to receive(:recent_incidents).and_return(
      Harassment::RecentIncidentsReport.build(server_id: "123", channel_id: "321", user_id: "456", incidents: [])
    )
    message = instance_double("Message", content: "!moderation harassment incidents <@456>")
    allow(event).to receive(:message).and_return(message)

    command.handle(event)

    expect(event).to have_received(:respond).with("No recent harassment incidents for <@456> in this channel")
  end

  it "responds with time-windowed incidents" do
    report = Harassment::RecentIncidentsReport.build(
      server_id: "123",
      channel_id: "321",
      user_id: nil,
      since: Time.utc(2026, 4, 25, 15, 0, 0),
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
          classified_at: Time.utc(2026, 4, 25, 16, 0, 0)
        )
      ]
    )
    allow(query_service).to receive(:recent_incidents).and_return(report)
    message = instance_double("Message", content: "!moderation harassment incidents 24h 1")
    allow(event).to receive(:message).and_return(message)
    freeze_time = Time.utc(2026, 4, 26, 15, 0, 0)
    allow(Time).to receive(:now).and_return(freeze_time)

    command.handle(event)

    expect(query_service).to have_received(:recent_incidents).with(
      123,
      321,
      limit: 1,
      user_id: nil,
      since: Time.utc(2026, 4, 25, 15, 0, 0)
    )
    expect(event).to have_received(:respond).with(a_string_including("Recent harassment incidents in the last 24h:"))
  end

  it "responds with time-windowed empty state for a user" do
    allow(query_service).to receive(:recent_incidents).and_return(
      Harassment::RecentIncidentsReport.build(
        server_id: "123",
        channel_id: "321",
        user_id: "456",
        since: Time.utc(2026, 4, 25, 15, 0, 0),
        incidents: []
      )
    )
    message = instance_double("Message", content: "!moderation harassment incidents <@456> 24h")
    allow(event).to receive(:message).and_return(message)
    allow(Time).to receive(:now).and_return(Time.utc(2026, 4, 26, 15, 0, 0))

    command.handle(event)

    expect(event).to have_received(:respond).with(
      "No recent harassment incidents for <@456> in the last 24h in this channel"
    )
  end

  it "accepts a user, limit, and window in flexible order" do
    report = Harassment::RecentIncidentsReport.build(
      server_id: "123",
      channel_id: "321",
      user_id: "456",
      since: Time.utc(2026, 4, 25, 15, 0, 0),
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
          classified_at: Time.utc(2026, 4, 25, 16, 0, 0)
        )
      ]
    )
    allow(query_service).to receive(:recent_incidents).and_return(report)
    message = instance_double("Message", content: "!moderation harassment incidents <@456> 1 24h")
    allow(event).to receive(:message).and_return(message)
    allow(Time).to receive(:now).and_return(Time.utc(2026, 4, 26, 15, 0, 0))

    command.handle(event)

    expect(query_service).to have_received(:recent_incidents).with(
      123,
      321,
      limit: 1,
      user_id: "456",
      since: Time.utc(2026, 4, 25, 15, 0, 0)
    )
    expect(event).to have_received(:respond).with(
      a_string_including("Recent harassment incidents for <@456> in the last 24h:")
    )
  end

  it "does not match incidents commands with duplicate window tokens" do
    message = instance_double("Message", content: "!moderation harassment incidents 24h 7d")
    allow(event).to receive(:message).and_return(message)

    expect(command.matches?(event)).to be(false)
  end
end
