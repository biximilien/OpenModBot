require_relative "review_presenter"

module Discord
  class ReviewCommand
    DEFAULT_LIMIT = 5
    MAX_LIMIT = 10

    def initialize(store:, usage:, presenter: ReviewPresenter.new)
      @store = store
      @usage = usage
      @presenter = presenter
    end

    def handle(event, match)
      case match[:subcommand]
      when nil, "recent" then respond_with_reviews(event, match)
      when "clear" then clear_reviews(event, match)
      when "repost", "restore" then repost_review(event, match)
      else event.respond(@usage)
      end
    end

    private

    def respond_with_reviews(event, match)
      return event.respond(@usage) if match[:subcommand] == "recent" && match[:user_id]

      entries = @store.get_moderation_reviews(
        event.server.id,
        review_limit(match),
        user_id: match[:user_id],
      )
      event.respond(@presenter.list(entries, user_id: match[:user_id]))
    end

    def clear_reviews(event, match)
      return event.respond(@usage) if match[:user_id] || match[:amount]

      @store.clear_moderation_reviews(event.server.id)
      event.respond("Cleared moderation review queue")
    end

    def repost_review(event, match)
      return event.respond(@usage) unless match[:amount]

      entry = @store.find_moderation_review(event.server.id, match[:amount])
      return event.respond("No moderation review found for message #{match[:amount]}") unless entry

      content = entry[:original_content].to_s.strip
      return event.respond("Original content was not stored for message #{match[:amount]}") if content.empty?

      event.respond(@presenter.reposted(entry))
    end

    def review_limit(match)
      limit = match[:amount]&.to_i || DEFAULT_LIMIT
      [[limit, 1].max, MAX_LIMIT].min
    end

  end
end
