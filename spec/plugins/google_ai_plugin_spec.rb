require "plugins/google_ai_plugin"

describe OpenModBot::Plugins::GoogleAIPlugin do
  around do |example|
    original = ENV.to_h
    example.run
  ensure
    ENV.replace(original)
  end

  it "exposes a Google AI provider" do
    expect(described_class.new.ai_provider).to be_a(GoogleAI::Provider)
  end

  it "configures the application AI provider during boot" do
    ENV["GOOGLE_AI_API_KEY"] = "google-key"
    app = instance_double("Application")
    plugin = described_class.new
    allow(app).to receive(:ai_provider=)

    plugin.boot(app:)

    expect(app).to have_received(:ai_provider=).with(plugin.ai_provider)
  end

  it "fails clearly when the API key is missing" do
    ENV.delete("GOOGLE_AI_API_KEY")

    expect { described_class.new.boot(app: instance_double("Application")) }.to raise_error(
      RuntimeError,
      "GOOGLE_AI_API_KEY is required when google_ai plugin is enabled"
    )
  end
end
