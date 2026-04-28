require_relative "../../environment"
require_relative "../logging"
require_relative "../moderation/rewrite_personalities"
require_relative "../plugin"

module ModerationGPT
  module Plugins
    class PersonalityPlugin < Plugin
      def rewrite_instructions(**)
        Moderation::RewritePersonalities.fetch(personality)
      end

      private

      def personality
        configured = Environment.personality
        return configured if Moderation::RewritePersonalities.known?(configured)

        Logging.warn("unknown_moderation_personality", configured_personality: configured, fallback_personality: Moderation::RewritePersonalities::DEFAULT)
        Moderation::RewritePersonalities::DEFAULT
      end
    end
  end
end
