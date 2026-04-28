require_relative "../environment"
require_relative "application"
require_relative "discord/moderation_command"
require_relative "discord/ready_handler"
require_relative "harassment/runtime/runtime"
require_relative "harassment/runtime/storage_config"
require_relative "harassment/runtime/worker_runner"
require_relative "moderation/message_router"
require_relative "moderation/strategies/remove_message_strategy"
require_relative "moderation/strategies/watch_list_strategy"
require_relative "plugin_registry"
require_relative "plugins/harassment_plugin"

module ModerationGPT
  RuntimeComponents = Struct.new(
    :app,
    :plugins,
    :harassment_runtime,
    :harassment_worker_runner,
    :moderation_command,
    :message_router,
    :ready_handler,
    keyword_init: true,
  )

  class RuntimeBuilder
    def initialize(app: Application.new, plugins: PluginRegistry.from_environment)
      @app = app
      @plugins = plugins
    end

    def build(bot:)
      @plugins.boot(app: @app, plugin_registry: @plugins)
      harassment_runtime = build_harassment_runtime

      RuntimeComponents.new(
        app: @app,
        plugins: @plugins,
        harassment_runtime: harassment_runtime,
        harassment_worker_runner: harassment_runtime ? Harassment::WorkerRunner.new(runtime: harassment_runtime) : nil,
        moderation_command: Discord::ModerationCommand.new(@app, plugin_commands: @plugins.commands),
        message_router: Moderation::MessageRouter.new(strategies),
        ready_handler: Discord::ReadyHandler.new(bot, @app),
      )
    end

    private

    def build_harassment_runtime
      harassment_plugin = @plugins.find_plugin(Plugins::HarassmentPlugin)
      return nil unless harassment_plugin

      storage_config = Harassment::StorageConfig.new(plugin_registry: @plugins)
      harassment_classification = harassment_plugin.classification_service

      Harassment::Runtime.new(
        redis: @app.redis,
        connection: storage_config.database_connection,
        storage_backend: storage_config.storage_backend,
        classifier_version: harassment_classification.classifier_version,
        classifier: harassment_classification.build_classifier(client: @app),
        on_classification: ->(event:, record:) { harassment_classification.record(event:, record:) },
      )
    end

    def strategies
      [
        WatchListStrategy.new(@app, plugin_registry: @plugins),
        RemoveMessageStrategy.new(@app, plugin_registry: @plugins),
      ] + @plugins.moderation_strategies(app: @app, plugin_registry: @plugins)
    end
  end
end
