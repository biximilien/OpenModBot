require "plugins/harassment_plugin"
require "harassment/plugin_bootstrap"
require_relative "../support/fake_postgres_connection"

describe ModerationGPT::Plugins::HarassmentPlugin do
  subject(:plugin) { described_class.new }
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
      server_id: "456",
      message_id: 123,
      classifier_version: "harassment-v1",
      model_version: "gpt-4o-2024-08-06",
      prompt_version: "harassment-prompt-v1",
      classification: { intent: "aggressive", target_type: "individual" },
      severity_score: 0.8,
      confidence: 0.5,
      classified_at: Time.utc(2026, 4, 25, 16, 0, 0),
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
    expect(risk_report.signals.keys).to match_array(%i[asymmetry persistence burst_intensity target_concentration average_severity])
    expect(plugin.query_service.get_pair_relationship("456", "321", "654", as_of: record.classified_at).relationship_edge.interaction_count).to eq(1)
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
    fake_connection = FakePostgresConnection.new
    app = instance_double("Application", redis: nil)
    postgres_plugin = instance_double(ModerationGPT::Plugins::PostgresPlugin, database_connection: fake_connection)
    plugin_registry = instance_double("PluginRegistry", find_plugin: postgres_plugin)
    original_backend = ENV["HARASSMENT_STORAGE_BACKEND"]
    ENV["HARASSMENT_STORAGE_BACKEND"] = "postgres"

    plugin.boot(app: app, plugin_registry: plugin_registry)
    plugin.classification_service.record(event:, record:)

    expect(plugin.query_service.get_pair_relationship("456", "321", "654", as_of: record.classified_at).relationship_edge.interaction_count).to eq(1)
  ensure
    ENV["HARASSMENT_STORAGE_BACKEND"] = original_backend
  end

  it "reconstructs recent incidents from Postgres-backed durable data after boot" do
    fake_connection = FakePostgresConnection.new
    Harassment::Repositories::PostgresInteractionEventRepository.new(connection: fake_connection).save(
      event.with_classification_status(Harassment::ClassificationStatus::CLASSIFIED),
    )
    Harassment::Repositories::PostgresClassificationRecordRepository.new(connection: fake_connection).save(record)
    app = instance_double("Application", redis: nil)
    postgres_plugin = instance_double(ModerationGPT::Plugins::PostgresPlugin, database_connection: fake_connection)
    plugin_registry = instance_double("PluginRegistry", find_plugin: postgres_plugin)
    original_backend = ENV["HARASSMENT_STORAGE_BACKEND"]
    ENV["HARASSMENT_STORAGE_BACKEND"] = "postgres"

    plugin.boot(app: app, plugin_registry: plugin_registry)
    report = plugin.query_service.recent_incidents("456", "789")

    expect(report.incidents.map(&:message_id)).to eq(["123"])
    expect(report.incidents.first.intent).to eq("aggressive")
  ensure
    ENV["HARASSMENT_STORAGE_BACKEND"] = original_backend
  end
end
