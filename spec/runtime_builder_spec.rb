require "runtime_builder"

describe OpenModBot::RuntimeBuilder do
  let(:app) { instance_double(OpenModBot::Application) }
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
    components = described_class.new(app:, plugins:).build(bot:)

    expect(plugins).to have_received(:boot).with(app:, plugin_registry: plugins)
    expect(components.app).to eq(app)
    expect(components.plugins).to eq(plugins)
    expect(components.moderation_command).to be_a(Discord::ModerationCommand)
    expect(components.message_router).to be_a(Moderation::MessageRouter)
    expect(components.ready_handler).to be_a(Discord::ReadyHandler)
  end
end
