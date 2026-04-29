require "plugins/personality_plugin"

describe OpenModBot::Plugins::PersonalityPlugin do
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

  it "supports the expanded moderation personality set" do
    expected_phrases = {
      "teacher" => "lightly instructional tone",
      "supportive" => "supportive, encouraging tone",
      "formal" => "polished, professional tone",
      "concise" => "as briefly as possible",
      "diplomatic" => "tactful, de-escalating tone",
      "coach" => "constructive coaching tone",
      "plainspoken" => "simple, everyday language",
      "legalistic" => "careful, precise tone",
      "community_manager" => "community-manager tone",
      "southern_charm" => "Southern-inspired voice",
      "shakespearean" => "Shakespearean style",
      "robot" => "robot-like voice",
      "zen" => "calm, minimal, de-escalating tone"
    }

    expected_phrases.each do |personality, phrase|
      ENV["PERSONALITY"] = personality

      expect(described_class.new.rewrite_instructions).to include(phrase)
    end
  end

  it "falls back to objective instructions for unknown personalities" do
    ENV["PERSONALITY"] = "wizard"
    allow(Logging.logger).to receive(:warn)

    instructions = described_class.new.rewrite_instructions

    expect(instructions).to include("direct, neutral tone")
    expect(Logging.logger).to have_received(:warn).with(
      event: "unknown_moderation_personality",
      configured_personality: "wizard",
      fallback_personality: "objective"
    )
  end
end
