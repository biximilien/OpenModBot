require "plugins/harassment_plugin"
require "harassment/runtime/plugin_bootstrap"
require_relative "../support/fake_postgres_connection"

describe OpenModBot::Plugins::HarassmentPlugin do
  subject(:plugin) { described_class.new }

  let(:event) do
    Harassment::InteractionEvent.build(
      message_id: 123,
      server_id: 456,
      channel_id: 789,
      author_id: 321,
      target_user_ids: [654],
      raw_content: "hello there"
    )
  end

  let(:record) do
    Harassment::ClassificationRecord.build(
      server_id: "456",
      message_id: 123,
      classifier_version: "harassment-v1",
      model_version: "gpt-4o-2024-08-06",
      prompt_version: "harassment-prompt-v1",
      classification: { intent: "aggressive", target_type: "individual" },
      severity_score: 0.8,
      confidence: 0.5,
      classified_at: Time.utc(2026, 4, 25, 16, 0, 0)
    )
  end
  let(:fake_connection) { FakePostgresConnection.new }
  let(:plugin_registry) { instance_double("PluginRegistry", postgres_connection: fake_connection) }
  let(:structured_app) do
    instance_double(
      "Application",
      generate_structured: { "output_text" => JSON.generate(structured_classification_payload) },
      response_text: nil
    )
  end
  let(:structured_classification_payload) do
    {
      intent: "aggressive",
      target_type: "individual",
      toxicity_dimensions: {
        insult: true,
        threat: false,
        profanity: false,
        exclusion: true,
        harassment: true
      },
      severity_score: 0.82,
      confidence: 0.77
    }
  end
  let(:discord_event) do
    mentioned_user = instance_double("User", id: 654)
    instance_double(
      "Event",
      message: instance_double(
        "Message",
        id: 123,
        content: "you're not welcome here",
        timestamp: Time.utc(2026, 4, 25, 16, 0, 0),
        mentions: [mentioned_user]
      ),
      server: instance_double("Server", id: 456),
      channel: instance_double("Channel", id: 789),
      user: instance_double("User", id: 321)
    )
  end

  it "exposes classification and query services" do
    incident = plugin.classification_service.record(event:, record:)

    expect(incident.intent).to eq("aggressive")
    expect(plugin.query_service.recent_incidents("456", "789").incidents).to eq([incident])
    expect(plugin.classification_service.classifier_version).to eq("harassment-v1")
  end

  it "exposes user risk and pair relationships" do
    plugin.classification_service.record(event:, record:)

    risk_report = plugin.query_service.get_user_risk("456", "321", as_of: record.classified_at)

    expect(risk_report.risk_score).to be_between(0.0, 1.0)
    expect(risk_report.signals.keys).to match_array(
      %i[asymmetry persistence burst_intensity target_concentration average_severity]
    )
    expect(
      plugin.query_service.get_pair_relationship(
        "456",
        "321",
        "654",
        as_of: record.classified_at
      ).relationship_edge.interaction_count
    ).to eq(1)
  end

  it "is idempotent for duplicate classification deliveries" do
    first = plugin.classification_service.record(event:, record:)
    second = plugin.classification_service.record(event:, record:)

    expect(first).to eq(second)
    expect(plugin.query_service.recent_incidents("456", "789").incidents.length).to eq(1)
    expect(plugin.query_service.get_pair_relationship("456", "321", "654").relationship_edge.interaction_count).to eq(1)
  end

  it "exposes a harassment moderation command" do
    expect(plugin.commands.length).to eq(1)
    expect(plugin.commands.first.help_lines).to include("!moderation harassment risk @user")
  end

  it "switches to Postgres relationship-edge storage on boot when configured" do
    app = instance_double("Application", redis: nil)

    plugin.boot(app: app, plugin_registry: plugin_registry)
    plugin.classification_service.record(event:, record:)

    expect(
      plugin.query_service.get_pair_relationship(
        "456",
        "321",
        "654",
        as_of: record.classified_at
      ).relationship_edge.interaction_count
    ).to eq(1)
  end

  it "reconstructs recent incidents from Postgres-backed durable data after boot" do
    Harassment::Repositories::PostgresInteractionEventRepository.new(connection: fake_connection).save(
      event.with_classification_status(Harassment::ClassificationStatus::CLASSIFIED)
    )
    Harassment::Repositories::PostgresClassificationRecordRepository.new(connection: fake_connection).save(record)
    app = instance_double("Application", redis: nil)

    plugin.boot(app: app, plugin_registry: plugin_registry)
    report = plugin.query_service.recent_incidents("456", "789")

    expect(report.incidents.map(&:message_id)).to eq(["123"])
    expect(report.incidents.first.intent).to eq("aggressive")
  end

  it "boots with Postgres and processes an ingested message through classification" do
    allow(structured_app).to receive(:response_text) { |response| response.fetch("output_text") }

    plugin.boot(app: structured_app, plugin_registry:)
    plugin.message(event: discord_event)
    runtime = plugin.instance_variable_get(:@runtime)
    results = runtime.process_due_classifications(as_of: Time.utc(2026, 4, 25, 16, 1, 0))

    expect(results.length).to eq(1)
    expect(runtime.classification_jobs.find(server_id: "456", message_id: "123",
                                            classifier_version: "harassment-v1").status)
      .to eq(Harassment::ClassificationStatus::CLASSIFIED)
    expect(runtime.classification_records.latest_for_message(server_id: "456", message_id: "123").severity_score)
      .to eq(0.82)
    expect(plugin.query_service.recent_incidents("456", "789").incidents.first.intent).to eq("aggressive")
    expect(plugin.query_service.get_user_risk("456", "321", as_of: Time.utc(2026, 4, 25, 16, 1, 0)).risk_score)
      .to be_positive
  end
end
