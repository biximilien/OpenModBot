require "harassment/risk/score_definition"

describe Harassment::ScoreDefinition do
  it "owns the harassment score version" do
    expect(described_class.new.version).to eq("harassment-score-v1")
  end
end
