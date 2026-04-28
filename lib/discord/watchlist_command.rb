module Discord
  class WatchlistCommand
    def initialize(store:, usage:)
      @store = store
      @usage = usage
    end

    def handle(event, match)
      return event.respond(@usage) if invalid_subcommand?(match)

      case match[:subcommand]
      when nil
        event.respond("Watch list: #{watch_list_mentions(event.server.id)}")
      when "add"
        add_watchlist_user(event, match)
      when "remove"
        remove_watchlist_user(event, match)
      else
        event.respond(@usage)
      end
    end

    private

    def invalid_subcommand?(match)
      match[:subcommand] && !%w[add remove].include?(match[:subcommand])
    end

    def add_watchlist_user(event, match)
      return event.respond(@usage) unless match[:user_id]

      @store.add_user_to_watch_list(event.server.id, match[:user_id].to_i)
      event.respond("Added <@#{match[:user_id]}> to watch list")
    end

    def remove_watchlist_user(event, match)
      return event.respond(@usage) unless match[:user_id]

      @store.remove_user_from_watch_list(event.server.id, match[:user_id].to_i)
      event.respond("Removed <@#{match[:user_id]}> from watch list")
    end

    def watch_list_mentions(server_id)
      mentions = @store.get_watch_list_users(server_id).map { |user_id| "<@#{user_id}>" }
      mentions.empty? ? "empty" : mentions.join(", ")
    end
  end
end
