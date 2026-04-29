require_relative "../environment"
require_relative "application"
require_relative "discord/moderation_command"
require_relative "discord/ready_handler"
require_relative "moderation/message_router"
require_relative "moderation/strategies/remove_message_strategy"
require_relative "moderation/strategies/watch_list_strategy"
require_relative "plugin_registry"

module OpenModBot
  RuntimeComponents = Struct.new(
    :app,
    :plugins,
    :moderation_command,
    :message_router,
    :ready_handler,
    keyword_init: true
  )

  class RuntimeBuilder
    def initialize(app: Application.new, plugins: PluginRegistry.from_environment)
      @app = app
      @plugins = plugins
    end

    def build(bot:)
      @plugins.boot(app: @app, bot: bot, plugin_registry: @plugins)
      configure_optional_capabilities

      RuntimeComponents.new(
        app: @app,
        plugins: @plugins,
        moderation_command: Discord::ModerationCommand.new(@app, plugin_commands: @plugins.commands),
        message_router: Moderation::MessageRouter.new(strategies),
        ready_handler: Discord::ReadyHandler.new(bot, @app)
      )
    end

    private

    def configure_optional_capabilities
      moderation_store = @plugins.capability(:moderation_store)
      @app.moderation_store = moderation_store if moderation_store
    end

    def strategies
      [
        WatchListStrategy.new(@app, plugin_registry: @plugins),
        RemoveMessageStrategy.new(@app, plugin_registry: @plugins)
      ] + @plugins.moderation_strategies(app: @app, plugin_registry: @plugins)
    end
  end
end
