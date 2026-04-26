require "harassment/repositories/postgres_relationship_edge_repository"
require_relative "../../support/fake_postgres_connection"

describe Harassment::Repositories::PostgresRelationshipEdgeRepository do
  subject(:repository) { described_class.new(connection: connection) }

  let(:connection) { FakePostgresConnection.new }
  let(:edge) do
    Harassment::RelationshipEdge.build(
      server_id: 456,
      source_user_id: 321,
      target_user_id: 654,
      score_version: "harassment-score-v1",
      hostility_score: 0.4,
      interaction_count: 1,
      last_interaction_at: Time.utc(2026, 4, 25, 16, 0, 0),
    )
  end

  it "stores and retrieves relationship edges" do
    repository.save(edge)

    expect(
      repository.find(
        server_id: "456",
        source_user_id: "321",
        target_user_id: "654",
        score_version: "harassment-score-v1",
      ),
    ).to eq(edge)
  end

  it "upserts updated edges" do
    repository.save(edge)
    updated = Harassment::RelationshipEdge.build(
      server_id: 456,
      source_user_id: 321,
      target_user_id: 654,
      score_version: "harassment-score-v1",
      hostility_score: 0.6,
      interaction_count: 2,
      last_interaction_at: Time.utc(2026, 4, 25, 17, 0, 0),
    )

    repository.save(updated)

    expect(
      repository.find(
        server_id: "456",
        source_user_id: "321",
        target_user_id: "654",
        score_version: "harassment-score-v1",
      ),
    ).to eq(updated)
  end

  it "returns outgoing and incoming edges by score version" do
    repository.save(edge)
    repository.save(
      Harassment::RelationshipEdge.build(
        server_id: 456,
        source_user_id: 999,
        target_user_id: 654,
        score_version: "harassment-score-v1",
        hostility_score: 0.2,
        interaction_count: 1,
        last_interaction_at: Time.utc(2026, 4, 25, 16, 5, 0),
      ),
    )

    expect(repository.outgoing(server_id: "456", source_user_id: "321", score_version: "harassment-score-v1")).to eq([edge])
    expect(repository.incoming(server_id: "456", target_user_id: "654", score_version: "harassment-score-v1").length).to eq(2)
  end
end
