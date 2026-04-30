module Discord
  class KarmaPresenter
    def score(user_id, karma)
      "Karma for <@#{user_id}>: #{karma}"
    end

    def reset(user_id)
      "Reset karma for <@#{user_id}>"
    end

    def set(user_id, karma)
      "Karma for <@#{user_id}> set to #{karma}"
    end

    def history(user_id, entries)
      return "No karma history for <@#{user_id}>" if entries.empty?

      lines = entries.map { |entry| history_line(entry) }
      "Karma history for <@#{user_id}>:\n#{lines.join("\n")}"
    end

    private

    def history_line(entry)
      actor = entry[:actor_id] ? " by <@#{entry[:actor_id]}>" : ""
      reason = entry[:reason] ? " (#{entry[:reason]})" : ""
      "- #{signed(entry[:delta])} => #{entry[:score]} via #{entry[:source]}#{actor} at #{entry[:created_at]}#{reason}"
    end

    def signed(value)
      value.positive? ? "+#{value}" : value.to_s
    end
  end
end
