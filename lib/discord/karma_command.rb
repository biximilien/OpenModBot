require_relative "karma_presenter"

module Discord
  class KarmaCommand
    DEFAULT_HISTORY_LIMIT = 5
    MAX_HISTORY_LIMIT = 10

    def initialize(store:, usage:, presenter: KarmaPresenter.new)
      @store = store
      @usage = usage
      @presenter = presenter
    end

    def handle(event, match)
      return event.respond(@usage) if invalid_subcommand?(match)

      case match[:subcommand]
      when nil then respond_with_karma(event, match)
      when "history" then respond_with_karma_history(event, match)
      when "reset" then reset_karma(event, match)
      when "set" then set_karma(event, match)
      when "add" then add_karma(event, match)
      when "remove" then remove_karma(event, match)
      else event.respond(@usage)
      end
    end

    private

    def invalid_subcommand?(match)
      match[:subcommand] && !%w[history reset set add remove].include?(match[:subcommand])
    end

    def respond_with_karma(event, match)
      return event.respond(@usage) unless match[:user_id]

      karma = @store.get_user_karma(event.server.id, match[:user_id].to_i)
      event.respond(@presenter.score(match[:user_id], karma))
    end

    def reset_karma(event, match)
      return event.respond(@usage) unless match[:user_id]

      @store.set_user_karma(event.server.id, match[:user_id].to_i, 0, actor_id: event.user.id)
      event.respond(@presenter.reset(match[:user_id]))
    end

    def set_karma(event, match)
      return event.respond(@usage) unless match[:user_id] && signed_amount(match)

      karma = @store.set_user_karma(event.server.id, match[:user_id].to_i, signed_amount(match),
                                    actor_id: event.user.id)
      event.respond(@presenter.set(match[:user_id], karma))
    end

    def add_karma(event, match)
      return event.respond(@usage) unless match[:user_id] && amount(match)

      karma = @store.increment_user_karma(event.server.id, match[:user_id].to_i, amount(match), actor_id: event.user.id)
      event.respond(@presenter.score(match[:user_id], karma))
    end

    def remove_karma(event, match)
      return event.respond(@usage) unless match[:user_id] && amount(match)

      karma = @store.decrement_user_karma(event.server.id, match[:user_id].to_i, amount(match), actor_id: event.user.id)
      event.respond(@presenter.score(match[:user_id], karma))
    end

    def respond_with_karma_history(event, match)
      return event.respond(@usage) unless match[:user_id]

      user_id = match[:user_id].to_i
      entries = @store.get_user_karma_history(event.server.id, user_id, history_limit(match))
      event.respond(@presenter.history(user_id, entries))
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
  end
end
