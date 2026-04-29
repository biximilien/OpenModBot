module OpenModBot
  module AI
    DEFAULT_REWRITE_INSTRUCTIONS = [
      "Rewrite the user's message in a direct, neutral tone.",
      "State the concern plainly, avoid emotional language, preserve the user's apparent intent,",
      "do not add new claims, and return only the rewritten message."
    ].join(" ").freeze
  end
end

require_relative "../open_mod_bot/compatibility"
