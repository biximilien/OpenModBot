require "harassment/pair_relationship_report"

describe Harassment::PairRelationshipReport do
  it "reports whether a relationship exists" do
    missing = described_class.build(source_user_id: 123, target_user_id: 456, relationship_edge: nil)
    found = described_class.build(
      source_user_id: 123,
      target_user_id: 456,
      relationship_edge: Harassment::RelationshipEdge.build(source_user_id: 123, target_user_id: 456),
    )

    expect(missing.found?).to eq(false)
    expect(found.found?).to eq(true)
  end
end
