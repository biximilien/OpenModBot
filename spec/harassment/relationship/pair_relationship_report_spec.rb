require "harassment/relationship/pair_relationship_report"

describe Harassment::PairRelationshipReport do
  it "reports whether a relationship exists" do
    missing = described_class.build(server_id: 789, source_user_id: 123, target_user_id: 456, relationship_edge: nil)
    found = described_class.build(
      server_id: 789,
      source_user_id: 123,
      target_user_id: 456,
      relationship_edge: Harassment::RelationshipEdge.build(server_id: 789, source_user_id: 123, target_user_id: 456, score_version: "harassment-score-v1"),
    )

    expect(missing.found?).to eq(false)
    expect(found.found?).to eq(true)
    expect(found.server_id).to eq("789")
    expect(found.score_version).to eq("harassment-score-v1")
  end
end
