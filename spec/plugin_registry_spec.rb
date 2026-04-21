require "plugin_registry"

describe ModerationGPT::PluginRegistry do
  around do |example|
    original = ENV.to_h
    original_catalog = described_class.catalog.dup
    original_load_path = $LOAD_PATH.dup
    example.run
  ensure
    ENV.replace(original)
    described_class.catalog.replace(original_catalog)
    $LOAD_PATH.replace(original_load_path)
  end

  describe ".register" do
    it "registers a plugin factory" do
      plugin = instance_double("Plugin")

      described_class.register("custom") { plugin }

      expect(described_class.catalog.fetch("custom").call).to eq(plugin)
    end
  end

  describe ".from_environment" do
    it "builds configured plugins" do
      plugin = instance_double("Plugin", commands: [])
      ENV["PLUGINS"] = "custom"

      registry = described_class.from_environment(catalog: { "custom" => -> { plugin } })

      expect(registry.commands).to eq([])
    end

    it "raises for unknown plugins" do
      ENV["PLUGINS"] = "missing"

      expect { described_class.from_environment(catalog: {}) }.to raise_error("Unknown plugin: missing")
    end

    it "loads external plugin requires before resolving plugins" do
      plugin_dir = File.expand_path("support/plugin_fixtures", __dir__)
      $LOAD_PATH.unshift(plugin_dir)
      ENV["PLUGIN_REQUIRES"] = "custom_plugin"
      ENV["PLUGINS"] = "custom"

      registry = described_class.from_environment

      expect(registry.commands).to eq([:custom_command])
    end

    it "raises a clear error when an external plugin require fails" do
      ENV["PLUGIN_REQUIRES"] = "missing_plugin"

      expect { described_class.from_environment }.to raise_error(/Could not load plugin require missing_plugin:/)
    end
  end

  describe "hooks" do
    it "dispatches lifecycle hooks to plugins" do
      plugin = instance_double(
        "Plugin",
        boot: true,
        ready: true,
        message: true,
        moderation_result: true,
        infraction: true,
        automod_outcome: true,
        rewrite_instructions: nil,
        commands: [:command],
      )
      registry = described_class.new([plugin])

      registry.boot(app: :app)
      registry.ready(event: :ready, app: :app, bot: :bot)
      registry.message(event: :message, app: :app, bot: :bot)
      registry.moderation_result(event: :event, result: :result, app: :app, strategy: "Strategy")
      registry.infraction(event: :event, score: -1, app: :app, strategy: "Strategy")
      registry.automod_outcome(event: :event, score: -5, outcome: "automod_timeout_applied", app: :app, strategy: "Strategy")

      expect(plugin).to have_received(:boot).with(app: :app)
      expect(plugin).to have_received(:ready).with(event: :ready, app: :app, bot: :bot)
      expect(plugin).to have_received(:message).with(event: :message, app: :app, bot: :bot)
      expect(plugin).to have_received(:moderation_result).with(event: :event, result: :result, app: :app, strategy: "Strategy")
      expect(plugin).to have_received(:infraction).with(event: :event, score: -1, app: :app, strategy: "Strategy")
      expect(plugin).to have_received(:automod_outcome).with(
        event: :event,
        score: -5,
        outcome: "automod_timeout_applied",
        app: :app,
        strategy: "Strategy",
      )
      expect(registry.commands).to eq([:command])
    end

    it "returns the first plugin rewrite instructions" do
      first = instance_double("Plugin", rewrite_instructions: nil)
      second = instance_double("Plugin", rewrite_instructions: "Rewrite this way.")

      result = described_class.new([first, second]).rewrite_instructions(event: :event)

      expect(result).to eq("Rewrite this way.")
      expect(first).to have_received(:rewrite_instructions).with(event: :event)
      expect(second).to have_received(:rewrite_instructions).with(event: :event)
    end

    it "logs and continues when a rewrite instruction hook fails" do
      broken = instance_double("Plugin")
      healthy = instance_double("Plugin", rewrite_instructions: "Fallback instructions.")
      allow(broken).to receive(:rewrite_instructions).and_raise(StandardError, "boom")
      allow($logger).to receive(:error)

      result = described_class.new([broken, healthy]).rewrite_instructions(event: :event)

      expect(result).to eq("Fallback instructions.")
      expect($logger).to have_received(:error).with("Plugin hook rewrite_instructions failed: StandardError: boom")
    end

    it "logs and continues when a plugin hook fails" do
      broken = instance_double("Plugin", message: nil)
      healthy = instance_double("Plugin", message: true)
      allow(broken).to receive(:message).and_raise(StandardError, "boom")
      allow($logger).to receive(:error)

      described_class.new([broken, healthy]).message(event: :message)

      expect($logger).to have_received(:error).with("Plugin hook message failed: StandardError: boom")
      expect(healthy).to have_received(:message).with(event: :message)
    end
  end
end
