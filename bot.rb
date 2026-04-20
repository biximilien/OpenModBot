require "discordrb"
require "logger"

require_relative "environment"
require_relative "lib/application"
require_relative "lib/discord"
require_relative "lib/discord/moderation_command"
require_relative "lib/discord/ready_handler"
require_relative "lib/discord/permission"
require_relative "lib/moderation_strategy"
require_relative "lib/moderation/message_router"
require_relative "lib/telemetry"
require_relative "lib/plugin_registry"

$logger = Logger.new(STDOUT)

Environment.validate!
plugins = ModerationGPT::PluginRegistry.from_environment
plugins.boot

bot = Discordrb::Bot.new token: Environment.discord_bot_token, intents: :all

if Environment.log_invite_url?
  $logger.info("This bot's invite URL is #{bot.invite_url(permission_bits: Discord::Permission::MODERATION_BOT)}.")
  $logger.info("Click on it to invite it to your server.")
end

app = ModerationGPT::Application.new

strategies = [
  WatchListStrategy.new(app, plugin_registry: plugins),
  RemoveMessageStrategy.new(app, plugin_registry: plugins),
]

moderation_command = Discord::ModerationCommand.new(app)
message_router = Moderation::MessageRouter.new(strategies)
ready_handler = Discord::ReadyHandler.new(bot, app)

bot.message do |event|
  next if event.user.current_bot?

  plugins.message(event: event, app: app, bot: bot)
  $logger.info("Message received: user=#{Telemetry::Anonymizer.hash(event.user.id)} length=#{event.message.content.length}")

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
  $logger.info("Exiting...")
  exit
end
