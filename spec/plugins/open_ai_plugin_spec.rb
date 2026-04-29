require "plugins/open_ai_plugin"

describe OpenModBot::Plugins::OpenAIPlugin do
  it "exposes an OpenAI provider" do
    expect(described_class.new.ai_provider).to be_a(OpenAI::Provider)
  end

  it "configures the application AI provider during boot" do
    app = instance_double("Application")
    plugin = described_class.new
    allow(app).to receive(:ai_provider=)

    plugin.boot(app:)

    expect(app).to have_received(:ai_provider=).with(plugin.ai_provider)
  end
end
