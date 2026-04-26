require "discordrb"
require "logger"

require_relative "environment"
require_relative "lib/application"
require_relative "lib/discord"
require_relative "lib/discord/moderation_command"
require_relative "lib/discord/ready_handler"
require_relative "lib/discord/permission"
require_relative "lib/moderation/strategy"
require_relative "lib/moderation/strategies/remove_message_strategy"
require_relative "lib/moderation/strategies/watch_list_strategy"
require_relative "lib/moderation/message_router"
require_relative "lib/telemetry"
require_relative "lib/plugin_registry"
require_relative "lib/logging"
require_relative "lib/harassment/runtime"
require_relative "lib/plugins/harassment_plugin"

$logger = Logging.build_logger(STDOUT)

Environment.validate!
app = ModerationGPT::Application.new
plugins = ModerationGPT::PluginRegistry.from_environment
plugins.boot(app: app)
harassment_plugin = plugins.find_plugin(ModerationGPT::Plugins::HarassmentPlugin)
harassment_runtime =
  if harassment_plugin
    Harassment::Runtime.new(
      redis: app.redis,
      connection: (Environment.harassment_storage_backend == "postgres" ? app.database_connection : nil),
      storage_backend: Environment.harassment_storage_backend,
      classifier_version: harassment_plugin.classifier_version,
      classifier: harassment_plugin.build_classifier(client: app),
      on_classification: ->(event:, record:) { harassment_plugin.record_classification(event:, record:) },
    )
  end
harassment_worker_thread = nil

bot = Discordrb::Bot.new token: Environment.discord_bot_token, intents: :all

if Environment.log_invite_url?
  Logging.info("discord_invite_url_generated", invite_url: bot.invite_url(permission_bits: Discord::Permission::MODERATION_BOT))
  Logging.info("discord_invite_url_notice")
end

strategies = [
  WatchListStrategy.new(app, plugin_registry: plugins),
  RemoveMessageStrategy.new(app, plugin_registry: plugins),
] + plugins.moderation_strategies(app: app, plugin_registry: plugins)

moderation_command = Discord::ModerationCommand.new(app, plugin_commands: plugins.commands)
message_router = Moderation::MessageRouter.new(strategies)
ready_handler = Discord::ReadyHandler.new(bot, app)

bot.message do |event|
  next if event.user.current_bot?

  if harassment_runtime
    interaction_event = harassment_runtime.ingest_message(event)
    Logging.info("harassment_interaction_enqueued", message_id: interaction_event.message_id, target_count: interaction_event.target_user_ids.length)
  end
  plugins.message(event: event, app: app, bot: bot)
  Logging.info("discord_message_received", user_hash: Telemetry::Anonymizer.hash(event.user.id), message_length: event.message.content.length)

  if moderation_command.matches?(event)
    moderation_command.handle(event)
  else
    message_router.handle(event)
  end
end

bot.ready do |event|
  if harassment_runtime && harassment_worker_thread.nil?
    harassment_worker_thread = Thread.new do
      Thread.current.name = "harassment-worker" if Thread.current.respond_to?(:name=)

      loop do
        harassment_runtime.process_due_classifications
        sleep 5
      end
    rescue StandardError => e
      Logging.error("harassment_worker_stopped", error_class: e.class.name, error_message: e.message)
    end
  end
  plugins.ready(event: event, app: app, bot: bot)
  ready_handler.handle(event)
end

begin
  at_exit do
    harassment_worker_thread&.kill
    bot.stop
  end
  bot.run
rescue Interrupt
  Logging.info("bot_stopping")
  exit
end
