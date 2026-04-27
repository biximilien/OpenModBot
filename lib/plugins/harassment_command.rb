require_relative "../harassment/discord/command_parser"
require_relative "../harassment/discord/command_presenter"

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

      def initialize(query_service, parser: Harassment::Discord::CommandParser.new, presenter: Harassment::Discord::CommandPresenter.new)
        @query_service = query_service
        @parser = parser
        @presenter = presenter
      end

      def matches?(event)
        !@parser.command_match(event.message.content).nil?
      end

      def handle(event)
        match = @parser.command_match(event.message.content)
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

      def handle_risk(event, match)
        report = @query_service.get_user_risk(event.server.id, match[:user_id], as_of: Time.now.utc)
        event.respond(@presenter.risk(report, user_id: match[:user_id]))
      end

      def handle_pair(event, match)
        report = @query_service.get_pair_relationship(event.server.id, match[:source_user_id], match[:target_user_id], as_of: Time.now.utc)
        event.respond(@presenter.pair(report, source_user_id: match[:source_user_id], target_user_id: match[:target_user_id]))
      end

      def handle_incidents(event, match)
        limit = [[match[:limit]&.to_i || DEFAULT_INCIDENT_LIMIT, 1].max, MAX_INCIDENT_LIMIT].min
        since = incident_window_start(match[:window])
        report = @query_service.recent_incidents(event.server.id, event.channel.id, limit:, user_id: match[:user_id], since:)
        event.respond(@presenter.incidents(report, user_id: match[:user_id], window: match[:window]))
      end

      def incident_window_start(window)
        return nil unless window

        Time.now.utc - Harassment::Discord::CommandParser::WINDOW_ALIASES.fetch(window)
      end
    end
  end
end
