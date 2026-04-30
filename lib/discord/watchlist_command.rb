require_relative "watchlist_presenter"

module Discord
  class WatchlistCommand
    def initialize(store:, usage:, presenter: WatchlistPresenter.new)
      @store = store
      @usage = usage
      @presenter = presenter
    end

    def handle(event, match)
      return event.respond(@usage) if invalid_subcommand?(match)

      case match[:subcommand]
      when nil
        event.respond(@presenter.list(@store.get_watch_list_users(event.server.id)))
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
      event.respond(@presenter.added(match[:user_id]))
    end

    def remove_watchlist_user(event, match)
      return event.respond(@usage) unless match[:user_id]

      @store.remove_user_from_watch_list(event.server.id, match[:user_id].to_i)
      event.respond(@presenter.removed(match[:user_id]))
    end
  end
end
