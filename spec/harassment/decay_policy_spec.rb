require "harassment/risk/decay_policy"

describe Harassment::DecayPolicy do
  it "returns the original score when no prior time is available" do
    policy = described_class.new

    expect(policy.decay(0.8, from: nil, to: Time.utc(2026, 4, 25, 12, 0, 0))).to eq(0.8)
  end

  it "applies exponential decay" do
    policy = described_class.new(lambda_value: Math.log(2) / 3600.0)

    decayed = policy.decay(1.0, from: Time.utc(2026, 4, 25, 12, 0, 0), to: Time.utc(2026, 4, 25, 13, 0, 0))

    expect(decayed).to be_within(0.0001).of(0.5)
  end

  it "rejects negative lambda values" do
    expect { described_class.new(lambda_value: -1) }.to raise_error(ArgumentError, "lambda_value must be non-negative")
  end
end
