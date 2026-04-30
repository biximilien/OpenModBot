require_relative "moderation_command_catalog"

module Discord
  class ModerationCommandParser
    TRIGGER_PATTERN = /\A!moderation\b/i
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

      command = shift_known(tokens, ModerationCommandCatalog.commands)
      subcommand = shift_known(tokens, ModerationCommandCatalog.subcommands)
      return nil unless ModerationCommandCatalog.allowed_subcommand?(command, subcommand)

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
  end
end
