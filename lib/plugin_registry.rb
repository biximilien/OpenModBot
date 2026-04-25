require_relative "../environment"
require_relative "logging"
require_relative "plugin"
require_relative "plugins/harassment_plugin"
require_relative "plugins/personality_plugin"
require_relative "plugins/telemetry_plugin"

module ModerationGPT
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
      each_plugin(:boot, **context)
    end

    def ready(**context)
      each_plugin(:ready, **context)
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

    def log_hook_failure(hook, error)
      Logging.error("plugin_hook_failed", hook: hook, error_class: error.class.name, error_message: error.message)
    end
  end

  PluginRegistry.register("harassment") { Plugins::HarassmentPlugin.new }
  PluginRegistry.register("personality") { Plugins::PersonalityPlugin.new }
  PluginRegistry.register("telemetry") { Plugins::TelemetryPlugin.new }
end
