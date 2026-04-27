module Harassment
  module Discord
    class CommandPresenter
    def risk(report, user_id:)
      signal_lines = report.signals.sort_by { |name, _| name.to_s }.map do |name, value|
        "- #{humanize_signal(name)}: #{format('%.2f', value)}"
      end
      [
        "Harassment risk for <@#{user_id}>",
        "Score: #{format('%.2f', report.risk_score)}",
        "Score version: #{report.score_version}",
        "Relationships: #{report.relationship_count}",
        "Signals:",
        *signal_lines,
      ].join("\n")
    end

    def pair(report, source_user_id:, target_user_id:)
      return "No harassment relationship found for <@#{source_user_id}> -> <@#{target_user_id}>" unless report.found?

      edge = report.relationship_edge
      [
        "Harassment relationship <@#{source_user_id}> -> <@#{target_user_id}>",
        "Hostility: #{format('%.2f', edge.hostility_score)}",
        "Score version: #{report.score_version}",
        "Interactions: #{edge.interaction_count}",
        "Last seen: #{edge.last_interaction_at.iso8601}",
      ].join("\n")
    end

    def incidents(report, user_id:, window:)
      return empty_incidents_message(user_id, window) if report.incidents.empty?

      lines = report.incidents.map do |incident|
        targets = incident.target_user_ids.empty? ? "none" : incident.target_user_ids.map { |target_user_id| "<@#{target_user_id}>" }.join(", ")
        "- <@#{incident.author_id}> -> #{targets} | #{incident.intent} | severity #{format('%.2f', incident.severity_score)} | confidence #{format('%.2f', incident.confidence)} | #{incident.classified_at.iso8601}"
      end
      "#{incidents_header(user_id, window)}\n#{lines.join("\n")}"
    end

    private

    def humanize_signal(name)
      name.to_s.split("_").map(&:capitalize).join(" ")
    end

    def incidents_header(user_id, window)
      scope = window ? " in the last #{window}" : ""
      return "Recent harassment incidents#{scope}:" unless user_id

      "Recent harassment incidents for <@#{user_id}>#{scope}:"
    end

    def empty_incidents_message(user_id, window)
      scope = window ? " in the last #{window}" : ""
      return "No recent harassment incidents#{scope} in this channel" unless user_id

      "No recent harassment incidents for <@#{user_id}>#{scope} in this channel"
    end
    end
  end
end
