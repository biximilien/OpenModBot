module Discord
  class WatchlistPresenter
    def list(user_ids)
      mentions = user_ids.map { |user_id| "<@#{user_id}>" }
      "Watch list: #{mentions.empty? ? "empty" : mentions.join(", ")}"
    end

    def added(user_id)
      "Added <@#{user_id}> to watch list"
    end

    def removed(user_id)
      "Removed <@#{user_id}> from watch list"
    end
  end
end
