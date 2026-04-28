require "discordrb"
require "logger"

require_relative "environment"
require_relative "lib/discord"
require_relative "lib/discord/permission"
require_relative "lib/telemetry"
require_relative "lib/logging"
require_relative "lib/runtime_builder"

$logger = Logging.build_logger(STDOUT)

Environment.validate!
bot = Discordrb::Bot.new token: Environment.discord_bot_token, intents: :all
runtime = ModerationGPT::RuntimeBuilder.new.build(bot:)
app = runtime.app
plugins = runtime.plugins
harassment_runtime = runtime.harassment_runtime
harassment_worker_runner = runtime.harassment_worker_runner

if Environment.log_invite_url?
  Logging.info("discord_invite_url_generated", invite_url: bot.invite_url(permission_bits: Discord::Permission::MODERATION_BOT))
  Logging.info("discord_invite_url_notice")
end

moderation_command = runtime.moderation_command
message_router = runtime.message_router
ready_handler = runtime.ready_handler

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
  harassment_worker_runner&.start
  plugins.ready(event: event, app: app, bot: bot)
  ready_handler.handle(event)
end

begin
  at_exit do
    harassment_worker_runner&.stop
    bot.stop
  end
  bot.run
rescue Interrupt
  Logging.info("bot_stopping")
  exit
end
