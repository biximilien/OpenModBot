require "runtime_builder"

describe OpenModBot::RuntimeBuilder do
  let(:app) { instance_double(OpenModBot::Application) }
  let(:ai_provider) { instance_double("AIProvider") }
  let(:moderation_store) { instance_double("ModerationStore") }
  let(:plugins) do
    instance_double(
      OpenModBot::PluginRegistry,
      boot: nil,
      capability: nil,
      commands: [],
      moderation_strategies: []
    )
  end
  let(:bot) { instance_double("DiscordBot") }

  it "boots plugins and builds core runtime components" do
    allow(plugins).to receive(:capability).with(:ai_provider).and_return(ai_provider)
    allow(plugins).to receive(:capability).with(:moderation_store).and_return(moderation_store)
    allow(app).to receive(:ai_provider=)
    allow(app).to receive(:moderation_store=)

    components = described_class.new(app:, plugins:).build(bot:)

    expect(plugins).to have_received(:boot).with(app:, bot:, plugin_registry: plugins)
    expect(app).to have_received(:ai_provider=).with(ai_provider)
    expect(app).to have_received(:moderation_store=).with(moderation_store)
    expect(components.app).to eq(app)
    expect(components.plugins).to eq(plugins)
    expect(components.moderation_command).to be_a(Discord::ModerationCommand)
    expect(components.message_router).to be_a(Moderation::MessageRouter)
    expect(components.ready_handler).to be_a(Discord::ReadyHandler)
  end
end
