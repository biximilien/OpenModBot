require_relative "../environment"
require_relative "logging"
require_relative "plugin"
require_relative "plugins/google_ai_plugin"
require_relative "plugins/harassment_plugin"
require_relative "plugins/open_ai_plugin"
require_relative "plugins/personality_plugin"
require_relative "plugins/postgres_plugin"
require_relative "plugins/redis_plugin"
require_relative "plugins/telemetry_plugin"

module OpenModBot
  class PluginRegistry
    def self.register(name, factory = nil, &block)
      catalog[name.to_s] = factory || block
    end

    def self.catalog
      @catalog ||= {}
    end

    def self.from_environment(catalog: self.catalog)
      load_external_plugins

      plugins = Environment.enabled_plugins.map do |name|
        factory = catalog.fetch(name) { raise "Unknown plugin: #{name}" }
        factory.call
      end

      new(plugins)
    end

    def self.load_external_plugins
      Environment.plugin_requires.each do |path|
        require path
      rescue LoadError => e
        raise "Could not load plugin require #{path}: #{e.message}"
      end
    end

    def initialize(plugins = [])
      @plugins = plugins
    end

    def boot(**context)
      @plugins.each { |plugin| plugin.boot(**context) }
    end

    def ready(**context)
      each_plugin(:ready, **context)
    end

    def shutdown(**context)
      each_plugin(:shutdown, **context)
    end

    def message(**context)
      each_plugin(:message, **context)
    end

    def moderation_result(**context)
      each_plugin(:moderation_result, **context)
    end

    def infraction(**context)
      each_plugin(:infraction, **context)
    end

    def automod_outcome(**context)
      each_plugin(:automod_outcome, **context)
    end

    def rewrite_instructions(**context)
      first_hook_result(:rewrite_instructions, **context)
    end

    def moderation_strategies(**context)
      flat_map_hook(:moderation_strategies, **context)
    end

    def commands
      flat_map_hook(:commands)
    end

    def ai_provider
      capability(:ai_provider) || first_hook_result(:ai_provider)
    end

    def postgres_connection
      capability(:postgres_connection) || legacy_postgres_connection
    end

    def capability(name)
      capability_name = name.to_sym
      @plugins.each do |plugin|
        next unless plugin.respond_to?(:capabilities)

        capabilities = plugin.capabilities
        next unless capabilities.key?(capability_name)

        value = capabilities.fetch(capability_name)
        return value if value
      end

      nil
    end

    def find_plugin(plugin_class)
      @plugins.find { |plugin| plugin.is_a?(plugin_class) }
    end

    private

    def each_plugin(hook, **context)
      @plugins.each do |plugin|
        plugin.public_send(hook, **context)
      rescue StandardError => e
        log_hook_failure(hook, e)
      end
    end

    def first_hook_result(hook, **context)
      @plugins.each do |plugin|
        result = plugin.public_send(hook, **context)
        return result if result
      rescue StandardError => e
        log_hook_failure(hook, e)
      end

      nil
    end

    def flat_map_hook(hook, **context)
      @plugins.flat_map do |plugin|
        plugin.public_send(hook, **context)
      rescue StandardError => e
        log_hook_failure(hook, e)
        []
      end
    end

    def legacy_postgres_connection
      @plugins.each do |plugin|
        connection = plugin.postgres_connection
        return connection if connection
      end

      nil
    end

    def log_hook_failure(hook, error)
      Logging.error("plugin_hook_failed", hook: hook, error_class: error.class.name, error_message: error.message)
    end
  end

  PluginRegistry.register("google_ai") { Plugins::GoogleAIPlugin.new }
  PluginRegistry.register("harassment") { Plugins::HarassmentPlugin.new }
  PluginRegistry.register("openai") { Plugins::OpenAIPlugin.new }
  PluginRegistry.register("personality") { Plugins::PersonalityPlugin.new }
  PluginRegistry.register("postgres") { Plugins::PostgresPlugin.new }
  PluginRegistry.register("redis") { Plugins::RedisPlugin.new }
  PluginRegistry.register("telemetry") { Plugins::TelemetryPlugin.new }
end
