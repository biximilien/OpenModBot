module Discord
  class ModerationCommandParser
    TRIGGER_PATTERN = /\A!moderation\b/i
    COMMANDS = %w[help watchlist karma review].freeze
    SUBCOMMANDS = %w[add remove reset history set recent clear restore repost].freeze
    ALLOWED_SUBCOMMANDS = {
      "help" => [],
      "watchlist" => %w[add remove],
      "karma" => %w[history reset set add remove],
      "review" => %w[recent clear restore repost],
    }.freeze
    MENTION_PATTERN = /\A<@!?(\d+)>\z/
    AMOUNT_PATTERN = /\A-?\d+\z/

    ParsedCommand = Struct.new(:command, :subcommand, :user_id, :amount, keyword_init: true) do
      def [](key)
        public_send(key)
      end
    end

    def trigger?(content)
      TRIGGER_PATTERN.match?(content)
    end

    def parse(content)
      tokens = content.to_s.strip.split(/\s+/)
      return nil unless tokens.shift&.casecmp("!moderation")&.zero?

      command = shift_known(tokens, COMMANDS)
      subcommand = shift_known(tokens, SUBCOMMANDS)
      return nil unless allowed_subcommand?(command, subcommand)

      user_id = shift_mention(tokens)
      amount = shift_amount(tokens)
      return nil unless tokens.empty?

      ParsedCommand.new(command:, subcommand:, user_id:, amount:)
    end

    def plugin_command_root?(match)
      match[:command].nil? && match[:subcommand].nil? && match[:user_id].nil? && match[:amount].nil?
    end

    private

    def shift_known(tokens, allowed)
      return nil if tokens.empty?
      return nil unless allowed.include?(tokens.first.downcase)

      tokens.shift.downcase
    end

    def shift_mention(tokens)
      return nil if tokens.empty?

      match = MENTION_PATTERN.match(tokens.first)
      return nil unless match

      tokens.shift
      match[1]
    end

    def shift_amount(tokens)
      return nil if tokens.empty?
      return nil unless AMOUNT_PATTERN.match?(tokens.first)

      tokens.shift
    end

    def allowed_subcommand?(command, subcommand)
      return subcommand.nil? unless command

      ALLOWED_SUBCOMMANDS.fetch(command).include?(subcommand) || subcommand.nil?
    end
  end
end
