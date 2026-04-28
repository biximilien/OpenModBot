module Discord
  class ReviewPresenter
    PREVIEW_LIMIT = 120
    RESPONSE_LIMIT = 1_800

    def list(entries, user_id: nil)
      subject = user_id ? " for <@#{user_id}>" : ""
      return "No moderation reviews#{subject}" if entries.empty?

      lines = capped_lines(entries, "Moderation reviews#{subject}:")
      "Moderation reviews#{subject}:\n#{lines.join("\n")}"
    end

    def reposted(entry)
      "Reposted message from <@#{entry[:user_id]}>:\n#{entry[:original_content].to_s.strip}"
    end

    private

    def capped_lines(entries, header)
      lines = []
      length = header.length + 1

      entries.each do |entry|
        next_line = line(entry)
        next_length = length + next_line.length + 1
        if next_length > RESPONSE_LIMIT
          remaining = entries.length - lines.length
          lines << "- #{remaining} more review#{'s' unless remaining == 1} omitted"
          break
        end

        lines << next_line
        length = next_length
      end

      lines
    end

    def line(entry)
      mode = entry[:shadow_mode] ? "shadow" : "live"
      rewrite = entry[:rewrite] ? " rewrite=#{preview(entry[:rewrite]).inspect}" : ""
      automod = entry[:automod_outcome] ? " automod=#{entry[:automod_outcome]}" : ""
      "- #{entry[:created_at]} #{mode} #{entry[:action]} <@#{entry[:user_id]}> msg=#{entry[:message_id]} via #{entry[:strategy]}#{automod}#{rewrite}"
    end

    def preview(value)
      text = value.to_s.gsub(/\s+/, " ").strip
      return text if text.length <= PREVIEW_LIMIT

      "#{text[0, PREVIEW_LIMIT]}..."
    end
  end
end
