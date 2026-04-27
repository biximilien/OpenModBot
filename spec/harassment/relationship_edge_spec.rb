require "harassment/relationship/edge"
require "harassment/risk/decay_policy"

describe Harassment::RelationshipEdge do
  it "builds a normalized relationship edge" do
    last_interaction_at = Time.utc(2026, 4, 25, 13, 0, 0)

    edge = described_class.build(
      server_id: 789,
      source_user_id: 123,
      target_user_id: 456,
      score_version: "harassment-score-v1",
      hostility_score: 0.75,
      positive_score: 0.25,
      interaction_count: 4,
      last_interaction_at: last_interaction_at,
    )

    expect(edge.source_user_id).to eq("123")
    expect(edge.target_user_id).to eq("456")
    expect(edge.score_version).to eq("harassment-score-v1")
    expect(edge.hostility_score).to eq(0.75)
    expect(edge.positive_score).to eq(0.25)
    expect(edge.interaction_count).to eq(4)
    expect(edge.last_interaction_at).to eq(last_interaction_at)
  end

  it "rejects negative scores or counts" do
    expect do
      described_class.build(
        server_id: 789,
        source_user_id: 123,
        target_user_id: 456,
        score_version: "harassment-score-v1",
        hostility_score: -0.1,
      )
    end.to raise_error(ArgumentError, "hostility_score must be non-negative")
  end

  it "decays scores to a later point in time" do
    edge = described_class.build(
      server_id: 789,
      source_user_id: 123,
      target_user_id: 456,
      score_version: "harassment-score-v1",
      hostility_score: 1.0,
      positive_score: 0.5,
      interaction_count: 1,
      last_interaction_at: Time.utc(2026, 4, 25, 12, 0, 0),
    )
    decay_policy = Harassment::DecayPolicy.new(lambda_value: Math.log(2) / 3600.0)

    decayed = edge.decay_to(as_of: Time.utc(2026, 4, 25, 13, 0, 0), decay_policy: decay_policy)

    expect(decayed.hostility_score).to be_within(0.0001).of(0.5)
    expect(decayed.positive_score).to be_within(0.0001).of(0.25)
    expect(decayed.score_version).to eq("harassment-score-v1")
    expect(decayed.interaction_count).to eq(1)
  end

  it "requires server identity and score version" do
    expect do
      described_class.build(source_user_id: 123, target_user_id: 456)
    end.to raise_error(ArgumentError, /missing keywords: :server_id, :score_version/)
  end
end
