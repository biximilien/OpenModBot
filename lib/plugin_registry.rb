require_relative "../environment"
require_relative "plugin"
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
      @plugins.each do |plugin|
        instructions = plugin.rewrite_instructions(**context)
        return instructions if instructions
      rescue StandardError => e
        $logger&.error("Plugin hook rewrite_instructions failed: #{e.class}: #{e.message}")
      end

      nil
    end

    def commands
      @plugins.flat_map(&:commands)
    end

    private

    def each_plugin(hook, **context)
      @plugins.each do |plugin|
        plugin.public_send(hook, **context)
      rescue StandardError => e
        $logger&.error("Plugin hook #{hook} failed: #{e.class}: #{e.message}")
      end
    end
  end

  PluginRegistry.register("personality") { Plugins::PersonalityPlugin.new }
  PluginRegistry.register("telemetry") { Plugins::TelemetryPlugin.new }
end
