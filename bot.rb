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

$logger = Logger.new(STDOUT)

Environment.validate!

bot = Discordrb::Bot.new token: Environment.discord_bot_token, intents: :all

if Environment.log_invite_url?
  $logger.info("This bot's invite URL is #{bot.invite_url(permission_bits: Discord::Permission::MODERATION_BOT)}.")
  $logger.info("Click on it to invite it to your server.")
end

app = ModerationGPT::Application.new

strategies = [
  WatchListStrategy.new(app),
  RemoveMessageStrategy.new(app),
]

moderation_command = Discord::ModerationCommand.new(app)
message_router = Moderation::MessageRouter.new(strategies)
ready_handler = Discord::ReadyHandler.new(bot, app)

bot.message do |event|
  next if event.user.current_bot?

  $logger.info("Message received: user=#{Telemetry::Anonymizer.hash(event.user.id)} length=#{event.message.content.length}")

  if moderation_command.matches?(event)
    moderation_command.handle(event)
  else
    message_router.handle(event)
  end
end

bot.ready do |event|
  ready_handler.handle(event)
end

begin
  at_exit { bot.stop }
  bot.run
rescue Interrupt
  $logger.info("Exiting...")
  exit
end
