require "discordrb"
require "logger"

require "./lib/open_ai"
require "./lib/discord"
require "./lib/discord/permission"
require "./lib/backend"
require "./lib/moderation_strategy"
require "./lib/opentelemetry"

# setup logging
$logger = Logger.new(STDOUT)

require "./environment"
Environment.validate!

# create bot
bot = Discordrb::Bot.new token: DISCORD_BOT_TOKEN, intents: :all

# Here we output the invite URL to the console so the bot account can be invited to the channel. This only has to be
# done once, afterwards, you can remove this part if you want
$logger.info("This bot's invite URL is #{bot.invite_url(permission_bits: Discord::Permission::ADMINISTRATOR)}.")
$logger.info("Click on it to invite it to your server.")

include Backend
include OpenAI

initialize_backend()

strategies = []
strategies << WatchListStrategy.new(self)
strategies << RemoveMessageStrategy.new(self)
# strategies << RewriteMessageStrategy.new

# bot commands
bot.message do |event|
  next if event.user.current_bot?

  $logger.info("Message from #{event.user.name} (#{event.user.id})")
  $logger.info(event.message.content)

  if /(?<trigger>!moderation)(\s(?<command>watchlist))?(\s(?<subcommand>add|remove)\s<@(?<user_id>\d+)>)?/i =~ event.message.content
    $logger.info("Moderation command from #{event.user.name} (#{event.user.id})")
    event.server.members.each do |member|
      # ensure triggering user has proper privileges
      if member.id == event.user.id && member.permission?(:administrator)
        # handle watchlist commands
        if trigger && command == "watchlist"
          if subcommand.nil?
            event.respond("Watch list: " + get_watch_list_users(event.server.id).map { |user_id| "<@#{user_id}>" }.join(", "))
          elsif subcommand == "add" && user_id
            add_user_to_watch_list(event.server.id, user_id.to_i)
            event.respond("Added <@#{user_id}> to watch list")
          elsif subcommand == "remove" && user_id
            remove_user_from_watch_list(event.server.id, user_id.to_i)
            event.respond("Removed <@#{user_id}> from watch list")
          else
            event.respond("Usage: !moderation watchlist [add|remove @user]")
          end
        else
          event.respond("Usage: !moderation watchlist [add|remove @user]")
        end
        # break early if we found the right user
        break
      end
    end
  else
    # execute enabled strategies
    strategies.each do |strategy|
      begin
        if strategy.condition(event)
          strategy.execute(event) and break
        end
      rescue StandardError => e
        $logger.error("Moderation strategy failed: #{e.class}: #{e.message}")
      end
    end
  end
end

# main loop
bot.ready do |event|
  $logger.info("Ready!")
  bot.online

  $logger.info("Servers: #{bot.servers.size}")

  bot.servers.each do |server_id, server|
    $logger.info("#{server.name} #{server.channels.size} #{server_id}}")

    # ensure server is in memory cache
    add_server(server_id)

    # debug
    server.channels.each do |channel|
      if channel.type == 0
        $logger.info("#{channel.name} #{channel.type} #{channel.id}")
      end
    end
  end
end

begin
  at_exit { bot.stop }
  bot.run
rescue Interrupt
  $logger.info("Exiting...")
  exit
end
