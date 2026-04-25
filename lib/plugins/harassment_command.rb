module ModerationGPT
  module Plugins
    class HarassmentCommand
      HELP_LINES = [
        "!moderation harassment risk @user",
        "!moderation harassment pair @user_a @user_b",
        "!moderation harassment incidents [limit]",
        "!moderation harassment incidents @user [limit]",
        "!moderation harassment incidents 24h [limit]",
        "!moderation harassment incidents @user 24h [limit]",
      ].freeze
      MAX_INCIDENT_LIMIT = 5
      DEFAULT_INCIDENT_LIMIT = 3
      WINDOW_ALIASES = {
        "1h" => 60 * 60,
        "24h" => 24 * 60 * 60,
        "7d" => 7 * 24 * 60 * 60,
      }.freeze
      INCIDENTS_PREFIX = "!moderation harassment incidents".freeze
      RISK_PATTERN = /\A!moderation harassment risk <@!?(?<user_id>\d+)>\s*\z/i.freeze
      PAIR_PATTERN = /\A!moderation harassment pair <@!?(?<source_user_id>\d+)>\s+<@!?(?<target_user_id>\d+)>\s*\z/i.freeze

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

        incidents_match = parse_incidents_command(content)
        return { type: :incidents, data: incidents_match } if incidents_match

        nil
      end

      def handle_risk(event, match)
        report = @plugin.get_user_risk(event.server.id, match[:user_id], as_of: Time.now.utc)
        signal_lines = report.signals.sort_by { |name, _| name.to_s }.map do |name, value|
          "- #{humanize_signal(name)}: #{format('%.2f', value)}"
        end
        event.respond(
          [
            "Harassment risk for <@#{match[:user_id]}>",
            "Score: #{format('%.2f', report.risk_score)}",
            "Score version: #{report.score_version}",
            "Relationships: #{report.relationship_count}",
            "Signals:",
            *signal_lines,
          ].join("\n"),
        )
      end

      def handle_pair(event, match)
        report = @plugin.get_pair_relationship(event.server.id, match[:source_user_id], match[:target_user_id], as_of: Time.now.utc)
        unless report.found?
          event.respond("No harassment relationship found for <@#{match[:source_user_id]}> -> <@#{match[:target_user_id]}>")
          return
        end

        edge = report.relationship_edge
        event.respond(
          [
            "Harassment relationship <@#{match[:source_user_id]}> -> <@#{match[:target_user_id]}>",
            "Hostility: #{format('%.2f', edge.hostility_score)}",
            "Score version: #{report.score_version}",
            "Interactions: #{edge.interaction_count}",
            "Last seen: #{edge.last_interaction_at.iso8601}",
          ].join("\n"),
        )
      end

      def handle_incidents(event, match)
        limit = [[match[:limit]&.to_i || DEFAULT_INCIDENT_LIMIT, 1].max, MAX_INCIDENT_LIMIT].min
        since = incident_window_start(match[:window])
        report = @plugin.recent_incidents(event.server.id, event.channel.id, limit:, user_id: match[:user_id], since:)
        if report.incidents.empty?
          event.respond(empty_incidents_message(match[:user_id], match[:window]))
          return
        end

        lines = report.incidents.map do |incident|
          targets = incident.target_user_ids.empty? ? "none" : incident.target_user_ids.map { |user_id| "<@#{user_id}>" }.join(", ")
          "- <@#{incident.author_id}> -> #{targets} | #{incident.intent} | severity #{format('%.2f', incident.severity_score)} | confidence #{format('%.2f', incident.confidence)} | #{incident.classified_at.iso8601}"
        end
        event.respond("#{incidents_header(match[:user_id], match[:window])}\n#{lines.join("\n")}")
      end

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

      def incident_window_start(window)
        return nil unless window

        Time.now.utc - WINDOW_ALIASES.fetch(window)
      end

      def parse_incidents_command(content)
        return nil unless content.downcase.start_with?(INCIDENTS_PREFIX)

        remainder = content[INCIDENTS_PREFIX.length..]&.strip
        return {} if remainder.nil? || remainder.empty?

        tokens = remainder.split(/\s+/)
        user_id = nil
        window = nil
        limit = nil

        tokens.each do |token|
          if (mention_match = /\A<@!?(?<user_id>\d+)>\z/.match(token))
            return nil if user_id

            user_id = mention_match[:user_id]
          elsif WINDOW_ALIASES.key?(token.downcase)
            return nil if window

            window = token.downcase
          elsif /\A\d+\z/.match?(token)
            return nil if limit

            limit = token
          else
            return nil
          end
        end

        { user_id:, window:, limit: }
      end
    end
  end
end
