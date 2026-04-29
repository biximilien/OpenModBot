require "plugins/postgres_plugin"

describe ModerationGPT::Plugins::PostgresPlugin do
  around do |example|
    original = ENV.to_h
    example.run
  ensure
    ENV.replace(original)
  end

  it "connects using DATABASE_URL" do
    connection = instance_double("PG::Connection")
    plugin = described_class.new
    ENV["DATABASE_URL"] = "postgres://postgres:postgres@localhost:5432/moderationgpt"
    stub_const("PG", class_double("PG", connect: connection))
    allow(plugin).to receive(:require).with("pg")
    allow(connection).to receive(:exec_params).and_return([])

    expect(plugin.database_connection).to eq(connection)
    expect(plugin.connection).to eq(connection)
    expect(plugin.postgres_connection).to eq(connection)
    expect(plugin.capabilities[:postgres_connection]).to eq(connection)
    expect(plugin.capabilities[:moderation_store]).to be_a(Moderation::Stores::PostgresStore)
    expect(PG).to have_received(:connect).once.with(ENV.fetch("DATABASE_URL"))
  end

  it "fails clearly when DATABASE_URL is missing" do
    ENV.delete("DATABASE_URL")

    expect { described_class.new.database_connection }.to raise_error(
      RuntimeError,
      "DATABASE_URL is required when postgres plugin is enabled"
    )
  end
end
