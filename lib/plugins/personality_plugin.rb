require_relative "../../environment"
require_relative "../plugin"

module ModerationGPT
  module Plugins
    class PersonalityPlugin < Plugin
      INSTRUCTIONS = {
        "objective" => "Rewrite the user's message in a direct, neutral tone. State the concern plainly, avoid emotional language, preserve the user's apparent intent, do not add new claims, and return only the rewritten message.",
        "empathetic" => "Rewrite the user's message in a calm, empathetic tone. Acknowledge tension without validating harmful language, preserve the user's apparent intent, do not add new claims, and return only the rewritten message.",
        "pirate" => "Rewrite the user's message in a light pirate voice while keeping it respectful and clear. Do not add threats, insults, or new claims. Preserve the user's apparent intent and return only the rewritten message.",
        "poetic" => "Rewrite the user's message in a concise poetic voice while keeping the meaning clear, respectful, and moderation-appropriate. Avoid obscure metaphors, do not add new claims, preserve the user's apparent intent, and return only the rewritten message.",
      }.freeze

      DEFAULT_PERSONALITY = "objective"

      def rewrite_instructions(**)
        INSTRUCTIONS.fetch(personality, INSTRUCTIONS.fetch(DEFAULT_PERSONALITY))
      end

      private

      def personality
        configured = Environment.personality
        return configured if INSTRUCTIONS.key?(configured)

        $logger&.warn("Unknown moderation personality #{configured.inspect}; using #{DEFAULT_PERSONALITY}")
        DEFAULT_PERSONALITY
      end
    end
  end
end
