require_relative "../telemetry/anonymizer"

module Discord
  class ModerationCommand
    USAGE = "Usage: !moderation watchlist [add|remove @user] OR !moderation karma @user OR !moderation karma reset @user OR !moderation karma [add|remove] @user amount".freeze
    TRIGGER_PATTERN = /\A!moderation\b/i.freeze
    COMMAND_PATTERN = /\A!moderation(?:\s+(?<command>watchlist|karma))?(?:\s+(?<subcommand>add|remove|reset))?(?:\s+<@!?(?<user_id>\d+)>)?(?:\s+(?<amount>\d+))?\s*\z/i.freeze

    def initialize(store)
      @store = store
    end

    def matches?(event)
      TRIGGER_PATTERN.match?(event.message.content)
    end

    def handle(event)
      match = COMMAND_PATTERN.match(event.message.content)
      return false unless matches?(event)

      $logger.info("Moderation command from user=#{Telemetry::Anonymizer.hash(event.user.id)}")
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
        event.respond(USAGE)
        return
      end

      case match[:command]
      when "watchlist" then respond_to_watchlist_command(event, match)
      when "karma" then respond_to_karma_command(event, match)
      else event.respond(USAGE)
      end
    end

    def respond_to_watchlist_command(event, match)
      case match[:subcommand]
      when nil
        event.respond("Watch list: #{watch_list_mentions(event.server.id)}")
      when "add"
        add_watchlist_user(event, match)
      when "remove"
        remove_watchlist_user(event, match)
      else
        event.respond(USAGE)
      end
    end

    def respond_to_karma_command(event, match)
      case match[:subcommand]
      when nil then respond_with_karma(event, match)
      when "reset" then reset_karma(event, match)
      when "add" then add_karma(event, match)
      when "remove" then remove_karma(event, match)
      else event.respond(USAGE)
      end
    end

    def add_watchlist_user(event, match)
      unless match[:user_id]
        event.respond(USAGE)
        return
      end

      @store.add_user_to_watch_list(event.server.id, match[:user_id].to_i)
      event.respond("Added <@#{match[:user_id]}> to watch list")
    end

    def remove_watchlist_user(event, match)
      unless match[:user_id]
        event.respond(USAGE)
        return
      end

      @store.remove_user_from_watch_list(event.server.id, match[:user_id].to_i)
      event.respond("Removed <@#{match[:user_id]}> from watch list")
    end

    def respond_with_karma(event, match)
      unless match[:user_id]
        event.respond(USAGE)
        return
      end

      karma = @store.get_user_karma(event.server.id, match[:user_id].to_i)
      event.respond("Karma for <@#{match[:user_id]}>: #{karma}")
    end

    def reset_karma(event, match)
      unless match[:user_id]
        event.respond(USAGE)
        return
      end

      @store.set_user_karma(event.server.id, match[:user_id].to_i, 0)
      event.respond("Reset karma for <@#{match[:user_id]}>")
    end

    def add_karma(event, match)
      adjust_karma(event, match, amount(match))
    end

    def remove_karma(event, match)
      adjust_karma(event, match, -amount(match))
    end

    def adjust_karma(event, match, delta)
      unless match[:user_id] && delta
        event.respond(USAGE)
        return
      end

      karma = @store.increment_user_karma(event.server.id, match[:user_id].to_i, delta)
      event.respond("Karma for <@#{match[:user_id]}>: #{karma}")
    end

    def amount(match)
      return nil unless match[:amount]

      value = match[:amount].to_i
      value.positive? ? value : nil
    end

    def watch_list_mentions(server_id)
      @store.get_watch_list_users(server_id).map { |user_id| "<@#{user_id}>" }.join(", ")
    end
  end
end
