require "plugins/personality_plugin"

describe ModerationGPT::Plugins::PersonalityPlugin do
  around do |example|
    original = ENV.to_h
    example.run
  ensure
    ENV.replace(original)
  end

  it "uses objective instructions by default" do
    ENV.delete("PERSONALITY")

    instructions = described_class.new.rewrite_instructions

    expect(instructions).to include("direct, neutral tone")
  end

  it "uses empathetic instructions when configured" do
    ENV["PERSONALITY"] = "empathetic"

    instructions = described_class.new.rewrite_instructions

    expect(instructions).to include("calm, empathetic tone")
  end

  it "uses pirate instructions when configured" do
    ENV["PERSONALITY"] = "pirate"

    instructions = described_class.new.rewrite_instructions

    expect(instructions).to include("light pirate voice")
  end

  it "uses poetic instructions when configured" do
    ENV["PERSONALITY"] = "poetic"

    instructions = described_class.new.rewrite_instructions

    expect(instructions).to include("concise poetic voice")
  end

  it "falls back to objective instructions for unknown personalities" do
    ENV["PERSONALITY"] = "wizard"
    allow($logger).to receive(:warn)

    instructions = described_class.new.rewrite_instructions

    expect(instructions).to include("direct, neutral tone")
    expect($logger).to have_received(:warn).with('Unknown moderation personality "wizard"; using objective')
  end
end
