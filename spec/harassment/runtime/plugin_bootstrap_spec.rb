require "harassment/runtime/plugin_bootstrap"
require "harassment/repositories/postgres_classification_record_repository"
require "harassment/repositories/postgres_interaction_event_repository"
require_relative "../../support/fake_postgres_connection"
require_relative "../../support/fake_redis"

describe Harassment::PluginBootstrap do
  let(:read_model) { Harassment::ReadModel.new(score_version: "harassment-score-v1") }

  it "keeps the existing read model for Redis storage" do
    app = instance_double("Application", redis: FakeRedis.new)

    configured = described_class.new(
      app: app,
      plugin_registry: nil,
      storage_backend: "redis",
      score_version: "harassment-score-v1",
      current_read_model: read_model
    ).build

    expect(configured.fetch(:read_model)).to eq(read_model)
    expect(configured.fetch(:query_service)).to be_a(Harassment::QueryService)
  end

  it "builds a durable read model and incident query for Postgres storage" do
    connection = FakePostgresConnection.new
    plugin_registry = instance_double("PluginRegistry", postgres_connection: connection)
    app = instance_double("Application", redis: nil)

    configured = described_class.new(
      app: app,
      plugin_registry: plugin_registry,
      storage_backend: "postgres",
      score_version: "harassment-score-v1",
      current_read_model: read_model
    ).build

    expect(configured.fetch(:read_model)).to be_a(Harassment::ReadModel)
    expect(configured.fetch(:read_model)).not_to eq(read_model)
    expect(configured.fetch(:query_service)).to be_a(Harassment::QueryService)
  end

  it "raises clearly when Postgres storage is configured without the Postgres plugin" do
    app = instance_double("Application", redis: nil)
    plugin_registry = instance_double("PluginRegistry", postgres_connection: nil)

    bootstrap = described_class.new(
      app: app,
      plugin_registry: plugin_registry,
      storage_backend: "postgres",
      score_version: "harassment-score-v1",
      current_read_model: read_model
    )

    expect { bootstrap.build }.to raise_error(
      RuntimeError,
      "harassment plugin requires the postgres plugin to be enabled"
    )
  end
end
