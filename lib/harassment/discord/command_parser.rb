module Harassment
  module Discord
    class CommandParser
    WINDOW_ALIASES = {
      "1h" => 60 * 60,
      "24h" => 24 * 60 * 60,
      "7d" => 7 * 24 * 60 * 60,
    }.freeze
    INCIDENTS_PREFIX = "!moderation harassment incidents".freeze
    RISK_PATTERN = /\A!moderation harassment risk <@!?(?<user_id>\d+)>\s*\z/i.freeze
    PAIR_PATTERN = /\A!moderation harassment pair <@!?(?<source_user_id>\d+)>\s+<@!?(?<target_user_id>\d+)>\s*\z/i.freeze

    def command_match(content)
      risk_match = RISK_PATTERN.match(content)
      return { type: :risk, data: risk_match } if risk_match

      pair_match = PAIR_PATTERN.match(content)
      return { type: :pair, data: pair_match } if pair_match

      incidents_match = parse_incidents_command(content)
      return { type: :incidents, data: incidents_match } if incidents_match

      nil
    end

    private

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
