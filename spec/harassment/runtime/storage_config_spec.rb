require "harassment/runtime/storage_config"

describe Harassment::StorageConfig do
  it "returns nil database connection for Redis storage" do
    registry = instance_double("PluginRegistry")

    config = described_class.new(plugin_registry: registry, storage_backend: "redis")

    expect(config.database_connection).to be_nil
    expect(config).not_to be_postgres
  end

  it "returns the Postgres plugin connection for Postgres storage" do
    connection = instance_double("Connection")
    registry = instance_double("PluginRegistry", postgres_connection: connection)

    config = described_class.new(plugin_registry: registry, storage_backend: "postgres")

    expect(config.database_connection).to eq(connection)
    expect(config).to be_postgres
  end

  it "raises clearly when Postgres storage is configured without the Postgres plugin" do
    registry = instance_double("PluginRegistry", postgres_connection: nil)
    config = described_class.new(plugin_registry: registry, storage_backend: "postgres")

    expect { config.database_connection }.to raise_error(
      RuntimeError,
      "HARASSMENT_STORAGE_BACKEND=postgres requires the postgres plugin to be enabled"
    )
  end
end
