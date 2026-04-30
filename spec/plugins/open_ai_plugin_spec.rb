require "plugins/open_ai_plugin"

describe OpenModBot::Plugins::OpenAIPlugin do
  it "exposes an OpenAI provider" do
    expect(described_class.new.ai_provider).to be_a(OpenAI::Provider)
  end

  it "initializes its provider during boot and exposes it as a capability" do
    plugin = described_class.new

    plugin.boot

    expect(plugin.capabilities[:ai_provider]).to eq(plugin.ai_provider)
  end
end
