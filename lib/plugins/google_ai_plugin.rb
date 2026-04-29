require_relative "../google_ai"
require_relative "../plugin"

module ModerationGPT
  module Plugins
    class GoogleAIPlugin < Plugin
      def boot(app:, **)
        raise "GOOGLE_AI_API_KEY is required when google_ai plugin is enabled" if missing_api_key?

        app.ai_provider = ai_provider
      end

      def ai_provider
        @ai_provider ||= GoogleAI::Provider.new
      end

      def capabilities
        { ai_provider: ai_provider }
      end

      private

      def missing_api_key?
        Environment.google_ai_api_key.nil? || Environment.google_ai_api_key.strip.empty?
      end
    end
  end
end
