module Discord
  module ModerationCommandCatalog
    DEFINITIONS = {
      "help" => {
        subcommands: [],
        help_lines: [
          "!moderation help"
        ]
      },
      "watchlist" => {
        subcommands: %w[add remove],
        help_lines: [
          "!moderation watchlist",
          "!moderation watchlist add @user",
          "!moderation watchlist remove @user"
        ]
      },
      "karma" => {
        subcommands: %w[history reset set add remove],
        help_lines: [
          "!moderation karma @user",
          "!moderation karma history @user [limit]",
          "!moderation karma set @user score",
          "!moderation karma reset @user",
          "!moderation karma add @user amount",
          "!moderation karma remove @user amount"
        ]
      },
      "review" => {
        subcommands: %w[recent clear restore repost],
        help_lines: [
          "!moderation review recent [limit]",
          "!moderation review @user [limit]",
          "!moderation review clear",
          "!moderation review repost message_id"
        ]
      }
    }.freeze

    def self.commands
      DEFINITIONS.keys
    end

    def self.subcommands
      DEFINITIONS.values.flat_map { |definition| definition.fetch(:subcommands) }.uniq
    end

    def self.allowed_subcommand?(command, subcommand)
      return subcommand.nil? unless command

      DEFINITIONS.fetch(command).fetch(:subcommands).include?(subcommand) || subcommand.nil?
    end

    def self.help_lines
      ["Moderation commands:"] + DEFINITIONS.values.flat_map { |definition| definition.fetch(:help_lines) }
    end
  end
end
