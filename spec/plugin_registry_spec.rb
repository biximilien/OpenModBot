require "plugin_registry"

describe OpenModBot::PluginRegistry do
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

    it "builds the built-in harassment plugin when postgres is enabled" do
      ENV["PLUGINS"] = "postgres,harassment"

      registry = described_class.from_environment

      expect(registry).to be_a(described_class)
      expect(registry.commands.length).to eq(1)
      expect(registry.commands.first.help_lines).to include("!moderation harassment risk @user")
      expect(registry.find_plugin(OpenModBot::Plugins::HarassmentPlugin)).to be_a(OpenModBot::Plugins::HarassmentPlugin)
    end

    it "raises clearly when a built-in plugin dependency is missing" do
      ENV["PLUGINS"] = "harassment"

      expect { described_class.from_environment }.to raise_error(
        RuntimeError,
        "Missing plugin dependencies: harassment requires postgres"
      )
    end

    it "builds the built-in postgres plugin" do
      ENV["PLUGINS"] = "postgres"

      registry = described_class.from_environment

      expect(registry.find_plugin(OpenModBot::Plugins::PostgresPlugin)).to be_a(OpenModBot::Plugins::PostgresPlugin)
    end

    it "builds the built-in Redis plugin" do
      ENV["PLUGINS"] = "redis"

      registry = described_class.from_environment

      expect(registry.find_plugin(OpenModBot::Plugins::RedisPlugin)).to be_a(OpenModBot::Plugins::RedisPlugin)
    end

    it "builds the built-in OpenAI plugin" do
      ENV["PLUGINS"] = "openai"

      registry = described_class.from_environment

      expect(registry.find_plugin(OpenModBot::Plugins::OpenAIPlugin)).to be_a(OpenModBot::Plugins::OpenAIPlugin)
      expect(registry.ai_provider).to be_a(OpenAI::Provider)
    end

    it "builds the built-in Google AI plugin" do
      ENV["PLUGINS"] = "google_ai"

      registry = described_class.from_environment

      expect(registry.find_plugin(OpenModBot::Plugins::GoogleAIPlugin)).to be_a(OpenModBot::Plugins::GoogleAIPlugin)
      expect(registry.ai_provider).to be_a(GoogleAI::Provider)
    end

    it "builds the built-in admin notifications plugin" do
      ENV["PLUGINS"] = "admin_notifications"

      registry = described_class.from_environment

      expect(registry.find_plugin(OpenModBot::Plugins::AdminNotificationsPlugin))
        .to be_a(OpenModBot::Plugins::AdminNotificationsPlugin)
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

      expect(registry.commands.length).to eq(1)
      expect(registry.commands.first).to respond_to(:matches?)
      expect(registry.commands.first).to respond_to(:handle)
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
        shutdown: true,
        message: true,
        moderation_result: true,
        infraction: true,
        automod_outcome: true,
        rewrite_instructions: nil,
        moderation_strategies: [],
        ai_provider: nil,
        commands: [:command]
      )
      registry = described_class.new([plugin])

      registry.boot(app: :app)
      registry.ready(event: :ready, app: :app, bot: :bot)
      registry.shutdown(app: :app, bot: :bot)
      registry.message(event: :message, app: :app, bot: :bot)
      registry.moderation_result(event: :event, result: :result, app: :app, strategy: "Strategy")
      registry.infraction(event: :event, score: -1, app: :app, strategy: "Strategy")
      registry.automod_outcome(event: :event, score: -5, outcome: "automod_timeout_applied", app: :app,
                               strategy: "Strategy")

      expect(plugin).to have_received(:boot).with(app: :app)
      expect(plugin).to have_received(:ready).with(event: :ready, app: :app, bot: :bot)
      expect(plugin).to have_received(:shutdown).with(app: :app, bot: :bot)
      expect(plugin).to have_received(:message).with(event: :message, app: :app, bot: :bot)
      expect(plugin).to have_received(:moderation_result).with(event: :event, result: :result, app: :app,
                                                               strategy: "Strategy")
      expect(plugin).to have_received(:infraction).with(event: :event, score: -1, app: :app, strategy: "Strategy")
      expect(plugin).to have_received(:automod_outcome).with(
        event: :event,
        score: -5,
        outcome: "automod_timeout_applied",
        app: :app,
        strategy: "Strategy"
      )
      expect(registry.commands).to eq([:command])
    end

    it "returns the first plugin AI provider" do
      provider = instance_double("AIProvider")
      first = instance_double("Plugin", ai_provider: nil)
      second = instance_double("Plugin", ai_provider: provider)

      expect(described_class.new([first, second]).ai_provider).to eq(provider)
    end

    it "returns a named plugin capability" do
      connection = instance_double("PG::Connection")
      first = instance_double("Plugin", capabilities: {})
      second = instance_double("Plugin", capabilities: { postgres_connection: connection })

      expect(described_class.new([first, second]).capability(:postgres_connection)).to eq(connection)
    end

    it "uses capabilities before legacy AI provider hooks" do
      provider = instance_double("AIProvider")
      plugin = instance_double("Plugin", capabilities: { ai_provider: provider }, ai_provider: nil)

      expect(described_class.new([plugin]).ai_provider).to eq(provider)
    end

    it "returns the first plugin Postgres connection" do
      connection = instance_double("PG::Connection")
      first = instance_double("Plugin", postgres_connection: nil)
      second = instance_double("Plugin", postgres_connection: connection)

      expect(described_class.new([first, second]).postgres_connection).to eq(connection)
    end

    it "does not swallow Postgres connection setup errors" do
      broken = instance_double("Plugin")
      allow(broken).to receive(:postgres_connection).and_raise(RuntimeError, "missing DATABASE_URL")

      expect { described_class.new([broken]).postgres_connection }.to raise_error(RuntimeError, "missing DATABASE_URL")
    end

    it "raises boot failures so required plugin configuration cannot be skipped" do
      broken = instance_double("Plugin")
      allow(broken).to receive(:boot).and_raise(StandardError, "boom")
      allow(Logging.logger).to receive(:error)

      expect { described_class.new([broken]).boot(app: :app) }.to raise_error(StandardError, "boom")
      expect(Logging.logger).not_to have_received(:error)
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
      allow(Logging.logger).to receive(:error)

      result = described_class.new([broken, healthy]).rewrite_instructions(event: :event)

      expect(result).to eq("Fallback instructions.")
      expect(Logging.logger).to have_received(:error).with(
        event: "plugin_hook_failed",
        hook: :rewrite_instructions,
        error_class: "StandardError",
        error_message: "boom"
      )
    end

    it "aggregates plugin-provided moderation strategies" do
      first = instance_double("Plugin", moderation_strategies: [:first])
      second = instance_double("Plugin", moderation_strategies: %i[second third])

      result = described_class.new([first, second]).moderation_strategies(app: :app, plugin_registry: :plugins)

      expect(result).to eq(%i[first second third])
      expect(first).to have_received(:moderation_strategies).with(app: :app, plugin_registry: :plugins)
      expect(second).to have_received(:moderation_strategies).with(app: :app, plugin_registry: :plugins)
    end

    it "logs and continues when a moderation strategy hook fails" do
      broken = instance_double("Plugin")
      healthy = instance_double("Plugin", moderation_strategies: [:healthy])
      allow(broken).to receive(:moderation_strategies).and_raise(StandardError, "boom")
      allow(Logging.logger).to receive(:error)

      result = described_class.new([broken, healthy]).moderation_strategies(app: :app)

      expect(result).to eq([:healthy])
      expect(Logging.logger).to have_received(:error).with(
        event: "plugin_hook_failed",
        hook: :moderation_strategies,
        error_class: "StandardError",
        error_message: "boom"
      )
    end

    it "logs and continues when a plugin hook fails" do
      broken = instance_double("Plugin", message: nil)
      healthy = instance_double("Plugin", message: true)
      allow(broken).to receive(:message).and_raise(StandardError, "boom")
      allow(Logging.logger).to receive(:error)

      described_class.new([broken, healthy]).message(event: :message)

      expect(Logging.logger).to have_received(:error).with(
        event: "plugin_hook_failed",
        hook: :message,
        error_class: "StandardError",
        error_message: "boom"
      )
      expect(healthy).to have_received(:message).with(event: :message)
    end
  end
end
