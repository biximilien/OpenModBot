require "runtime_builder"

describe ModerationGPT::RuntimeBuilder do
  let(:app) { instance_double(ModerationGPT::Application) }
  let(:plugins) do
    instance_double(
      ModerationGPT::PluginRegistry,
      boot: nil,
      commands: [],
      find_plugin: nil,
      moderation_strategies: [],
    )
  end
  let(:bot) { instance_double("DiscordBot") }

  it "boots plugins and builds core runtime components" do
    components = described_class.new(app:, plugins:).build(bot:)

    expect(plugins).to have_received(:boot).with(app:, plugin_registry: plugins)
    expect(components.app).to eq(app)
    expect(components.plugins).to eq(plugins)
    expect(components.harassment_runtime).to be_nil
    expect(components.harassment_worker_runner).to be_nil
    expect(components.moderation_command).to be_a(Discord::ModerationCommand)
    expect(components.message_router).to be_a(Moderation::MessageRouter)
    expect(components.ready_handler).to be_a(Discord::ReadyHandler)
  end
end
