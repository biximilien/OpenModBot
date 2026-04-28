require_relative "../telemetry/anonymizer"
require_relative "../logging"
require_relative "karma_command"
require_relative "moderation_command_parser"
require_relative "review_command"
require_relative "watchlist_command"

module Discord
  class ModerationCommand
    USAGE = "Usage: !moderation help".freeze
    BASE_HELP_LINES = [
      "Moderation commands:",
      "!moderation watchlist",
      "!moderation watchlist add @user",
      "!moderation watchlist remove @user",
      "!moderation karma @user",
      "!moderation karma history @user [limit]",
      "!moderation karma set @user score",
      "!moderation karma reset @user",
      "!moderation karma add @user amount",
      "!moderation karma remove @user amount",
      "!moderation review recent [limit]",
      "!moderation review @user [limit]",
      "!moderation review clear",
      "!moderation review repost message_id",
    ].freeze
    HELP_TEXT = BASE_HELP_LINES.join("\n").freeze

    def initialize(store, plugin_commands: [], parser: ModerationCommandParser.new)
      @store = store
      @plugin_commands = plugin_commands
      @parser = parser
      @watchlist_command = WatchlistCommand.new(store:, usage: USAGE)
      @karma_command = KarmaCommand.new(store:, usage: USAGE)
      @review_command = ReviewCommand.new(store:, usage: USAGE)
    end

    def matches?(event)
      @parser.trigger?(event.message.content)
    end

    def handle(event)
      match = @parser.parse(event.message.content)
      return false unless matches?(event)

      Logging.info("moderation_command_received", user_hash: Telemetry::Anonymizer.hash(event.user.id))
      return true unless administrator?(event)

      respond_to_command(event, match)
      true
    end

    private

    def administrator?(event)
      event.server.members.any? do |member|
        member.id == event.user.id && member.permission?(:administrator)
      end
    end

    def respond_to_command(event, match)
      unless match
        return if handle_plugin_command(event)

        event.respond(USAGE)
        return
      end

      if @parser.plugin_command_root?(match)
        return if handle_plugin_command(event)
      end

      case match[:command]
      when "help", nil then respond_to_help_command(event, match)
      when "watchlist" then @watchlist_command.handle(event, match)
      when "karma" then @karma_command.handle(event, match)
      when "review" then @review_command.handle(event, match)
      else event.respond(USAGE)
      end
    end

    def handle_plugin_command(event)
      command = @plugin_commands.find { |plugin_command| plugin_command.matches?(event) }
      return false unless command

      command.handle(event)
      true
    end

    def help_text
      (BASE_HELP_LINES + plugin_help_lines).join("\n")
    end

    def plugin_help_lines
      @plugin_commands.flat_map do |command|
        Array(command.respond_to?(:help_lines) ? command.help_lines : nil)
      end
    end

    def respond_to_help_command(event, match)
      unless match
        event.respond(help_text)
        return
      end

      if match[:subcommand] || match[:user_id] || match[:amount]
        event.respond(USAGE)
      else
        event.respond(help_text)
      end
    end

  end
end
