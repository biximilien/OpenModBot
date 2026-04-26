require "harassment/repositories/postgres_server_rate_limit_repository"
require_relative "../../support/fake_postgres_connection"

describe Harassment::Repositories::PostgresServerRateLimitRepository do
  subject(:repository) { described_class.new(connection: connection) }

  let(:connection) { FakePostgresConnection.new }
  let(:timestamps) do
    [
      Time.utc(2026, 4, 25, 15, 0, 0),
      Time.utc(2026, 4, 25, 15, 0, 30),
    ]
  end

  it "stores and fetches timestamps by server id" do
    repository.save("456", timestamps)

    expect(repository.fetch("456")).to eq(timestamps)
  end

  it "returns an empty array when no timestamps exist" do
    expect(repository.fetch("456")).to eq([])
  end
end
