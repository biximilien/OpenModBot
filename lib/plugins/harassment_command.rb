module ModerationGPT
  module Plugins
    class HarassmentCommand
      HELP_LINES = [
        "!moderation harassment risk @user",
        "!moderation harassment pair @user_a @user_b",
        "!moderation harassment incidents [limit]",
      ].freeze
      MAX_INCIDENT_LIMIT = 5
      DEFAULT_INCIDENT_LIMIT = 3
      RISK_PATTERN = /\A!moderation harassment risk <@!?(?<user_id>\d+)>\s*\z/i.freeze
      PAIR_PATTERN = /\A!moderation harassment pair <@!?(?<source_user_id>\d+)>\s+<@!?(?<target_user_id>\d+)>\s*\z/i.freeze
      INCIDENTS_PATTERN = /\A!moderation harassment incidents(?:\s+(?<limit>\d+))?\s*\z/i.freeze

      def initialize(plugin)
        @plugin = plugin
      end

      def matches?(event)
        !command_match(event.message.content).nil?
      end

      def handle(event)
        match = command_match(event.message.content)
        return unless match

        case match[:type]
        when :risk then handle_risk(event, match[:data])
        when :pair then handle_pair(event, match[:data])
        when :incidents then handle_incidents(event, match[:data])
        end
      end

      def help_lines
        HELP_LINES
      end

      private

      def command_match(content)
        risk_match = RISK_PATTERN.match(content)
        return { type: :risk, data: risk_match } if risk_match

        pair_match = PAIR_PATTERN.match(content)
        return { type: :pair, data: pair_match } if pair_match

        incidents_match = INCIDENTS_PATTERN.match(content)
        return { type: :incidents, data: incidents_match } if incidents_match

        nil
      end

      def handle_risk(event, match)
        report = @plugin.get_user_risk(match[:user_id], as_of: Time.now.utc)
        signal_lines = report.signals.sort_by { |name, _| name.to_s }.map do |name, value|
          "- #{humanize_signal(name)}: #{format('%.2f', value)}"
        end
        event.respond(
          [
            "Harassment risk for <@#{match[:user_id]}>",
            "Score: #{format('%.2f', report.risk_score)}",
            "Relationships: #{report.relationship_count}",
            "Signals:",
            *signal_lines,
          ].join("\n"),
        )
      end

      def handle_pair(event, match)
        report = @plugin.get_pair_relationship(match[:source_user_id], match[:target_user_id], as_of: Time.now.utc)
        unless report.found?
          event.respond("No harassment relationship found for <@#{match[:source_user_id]}> -> <@#{match[:target_user_id]}>")
          return
        end

        edge = report.relationship_edge
        event.respond(
          [
            "Harassment relationship <@#{match[:source_user_id]}> -> <@#{match[:target_user_id]}>",
            "Hostility: #{format('%.2f', edge.hostility_score)}",
            "Interactions: #{edge.interaction_count}",
            "Last seen: #{edge.last_interaction_at.iso8601}",
          ].join("\n"),
        )
      end

      def handle_incidents(event, match)
        limit = [[match[:limit]&.to_i || DEFAULT_INCIDENT_LIMIT, 1].max, MAX_INCIDENT_LIMIT].min
        report = @plugin.recent_incidents(event.channel.id, limit:)
        if report.incidents.empty?
          event.respond("No recent harassment incidents in this channel")
          return
        end

        lines = report.incidents.map do |incident|
          targets = incident.target_user_ids.empty? ? "none" : incident.target_user_ids.map { |user_id| "<@#{user_id}>" }.join(", ")
          "- <@#{incident.author_id}> -> #{targets} | #{incident.intent} | severity #{format('%.2f', incident.severity_score)} | confidence #{format('%.2f', incident.confidence)} | #{incident.classified_at.iso8601}"
        end
        event.respond("Recent harassment incidents:\n#{lines.join("\n")}")
      end

      def humanize_signal(name)
        name.to_s.split("_").map(&:capitalize).join(" ")
      end
    end
  end
end
