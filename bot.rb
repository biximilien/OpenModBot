require "discordrb"
require "logger"

require_relative "environment"
require_relative "lib/discord"
require_relative "lib/discord/permission"
require_relative "lib/telemetry"
require_relative "lib/logging"
require_relative "lib/runtime_builder"

Logging.logger = Logging.build_logger($stdout)

Environment.validate!
bot = Discordrb::Bot.new token: Environment.discord_bot_token, intents: :all
runtime = OpenModBot::RuntimeBuilder.new.build(bot:)
app = runtime.app
plugins = runtime.plugins

if Environment.log_invite_url?
  Logging.info("discord_invite_url_generated", invite_url: bot.invite_url(permission_bits: Discord::Permission::MODERATION_BOT))
  Logging.info("discord_invite_url_notice")
end

moderation_command = runtime.moderation_command
message_router = runtime.message_router
ready_handler = runtime.ready_handler

bot.message do |event|
  next if event.user.current_bot?

  plugins.message(event: event, app: app, bot: bot)
  Logging.info("discord_message_received", user_hash: Telemetry::Anonymizer.hash(event.user.id),
                                           message_length: event.message.content.length)

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
  at_exit do
    plugins.shutdown(app: app, bot: bot)
    bot.stop
  end
  bot.run
rescue Interrupt
  Logging.info("bot_stopping")
  exit
end
