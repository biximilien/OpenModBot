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

$logger = Logging.build_logger(STDOUT)

Environment.validate!
plugins = ModerationGPT::PluginRegistry.from_environment
plugins.boot

bot = Discordrb::Bot.new token: Environment.discord_bot_token, intents: :all

if Environment.log_invite_url?
  Logging.info("discord_invite_url_generated", invite_url: bot.invite_url(permission_bits: Discord::Permission::MODERATION_BOT))
  Logging.info("discord_invite_url_notice")
end

app = ModerationGPT::Application.new

strategies = [
  WatchListStrategy.new(app, plugin_registry: plugins),
  RemoveMessageStrategy.new(app, plugin_registry: plugins),
] + plugins.moderation_strategies(app: app, plugin_registry: plugins)

moderation_command = Discord::ModerationCommand.new(app, plugin_commands: plugins.commands)
message_router = Moderation::MessageRouter.new(strategies)
ready_handler = Discord::ReadyHandler.new(bot, app)

bot.message do |event|
  next if event.user.current_bot?

  plugins.message(event: event, app: app, bot: bot)
  Logging.info("discord_message_received", user_hash: Telemetry::Anonymizer.hash(event.user.id), message_length: event.message.content.length)

  if moderation_command.matches?(event)
    moderation_command.handle(event)
  else
    message_router.handle(event)
  end
end

bot.ready do |event|
  plugins.ready(event: event, app: app, bot: bot)
  ready_handler.handle(event)
end

begin
  at_exit { bot.stop }
  bot.run
rescue Interrupt
  Logging.info("bot_stopping")
  exit
end
