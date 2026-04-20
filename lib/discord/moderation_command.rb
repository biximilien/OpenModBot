require_relative "../telemetry/anonymizer"

module Discord
  class ModerationCommand
    DEFAULT_HISTORY_LIMIT = 5
    MAX_HISTORY_LIMIT = 10
    USAGE = "Usage: !moderation help".freeze
    HELP_TEXT = [
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
    ].join("\n").freeze
    TRIGGER_PATTERN = /\A!moderation\b/i.freeze
    COMMAND_PATTERN = /\A!moderation(?:\s+(?<command>help|watchlist|karma))?(?:\s+(?<subcommand>add|remove|reset|history|set))?(?:\s+<@!?(?<user_id>\d+)>)?(?:\s+(?<amount>-?\d+))?\s*\z/i.freeze

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
      when "help", nil then respond_to_help_command(event, match)
      when "watchlist" then respond_to_watchlist_command(event, match)
      when "karma" then respond_to_karma_command(event, match)
      else event.respond(USAGE)
      end
    end

    def respond_to_help_command(event, match)
      if match[:subcommand] || match[:user_id] || match[:amount]
        event.respond(USAGE)
      else
        event.respond(HELP_TEXT)
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
      when "history" then respond_with_karma_history(event, match)
      when "reset" then reset_karma(event, match)
      when "set" then set_karma(event, match)
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

      @store.set_user_karma(event.server.id, match[:user_id].to_i, 0, actor_id: event.user.id)
      event.respond("Reset karma for <@#{match[:user_id]}>")
    end

    def set_karma(event, match)
      unless match[:user_id] && signed_amount(match)
        event.respond(USAGE)
        return
      end

      karma = @store.set_user_karma(event.server.id, match[:user_id].to_i, signed_amount(match), actor_id: event.user.id)
      event.respond("Karma for <@#{match[:user_id]}> set to #{karma}")
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

      karma = @store.increment_user_karma(event.server.id, match[:user_id].to_i, delta, actor_id: event.user.id)
      event.respond("Karma for <@#{match[:user_id]}>: #{karma}")
    end

    def respond_with_karma_history(event, match)
      unless match[:user_id]
        event.respond(USAGE)
        return
      end

      user_id = match[:user_id].to_i
      entries = @store.get_user_karma_history(event.server.id, user_id, history_limit(match))
      event.respond(karma_history_response(user_id, entries))
    end

    def amount(match)
      return nil unless match[:amount]

      value = match[:amount].to_i
      value.positive? ? value : nil
    end

    def signed_amount(match)
      return nil unless match[:amount]

      match[:amount].to_i
    end

    def history_limit(match)
      [amount(match) || DEFAULT_HISTORY_LIMIT, MAX_HISTORY_LIMIT].min
    end

    def karma_history_response(user_id, entries)
      return "No karma history for <@#{user_id}>" if entries.empty?

      lines = entries.map { |entry| karma_history_line(entry) }
      "Karma history for <@#{user_id}>:\n#{lines.join("\n")}"
    end

    def karma_history_line(entry)
      actor = entry[:actor_id] ? " by <@#{entry[:actor_id]}>" : ""
      reason = entry[:reason] ? " (#{entry[:reason]})" : ""
      "- #{signed(entry[:delta])} => #{entry[:score]} via #{entry[:source]}#{actor} at #{entry[:created_at]}#{reason}"
    end

    def signed(value)
      value.positive? ? "+#{value}" : value.to_s
    end

    def watch_list_mentions(server_id)
      mentions = @store.get_watch_list_users(server_id).map { |user_id| "<@#{user_id}>" }
      mentions.empty? ? "empty" : mentions.join(", ")
    end
  end
end
