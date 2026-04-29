require_relative "../../environment"
require "ai/provider_config"

describe OpenModBot::AI::ProviderConfig do
  around do |example|
    original = ENV.to_h
    example.run
  ensure
    ENV.replace(original)
  end

  it "defaults to OpenAI when no AI provider plugin is configured" do
    config = described_class.new(enabled_plugins: [])

    expect(config.provider_name).to eq("openai")
    expect(config.api_key_variable).to eq("OPENAI_API_KEY")
    expect(config.classifier_model).to eq("gpt-4o-2024-08-06")
  end

  it "uses the last configured AI provider plugin" do
    config = described_class.new(enabled_plugins: %w[google_ai openai])

    expect(config.provider_name).to eq("openai")
    expect(config.api_key_variable).to eq("OPENAI_API_KEY")
  end

  it "uses the Google AI model for the Google AI classifier default" do
    ENV["GOOGLE_AI_MODEL"] = "gemini-test"

    config = described_class.new(enabled_plugins: ["google_ai"])

    expect(config.provider_name).to eq("google_ai")
    expect(config.api_key_variable).to eq("GOOGLE_AI_API_KEY")
    expect(config.classifier_model).to eq("gemini-test")
  end
end
