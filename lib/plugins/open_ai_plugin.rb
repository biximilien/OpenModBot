require_relative "../open_ai"
require_relative "../plugin"

module OpenModBot
  module Plugins
    class OpenAIPlugin < Plugin
      def boot(**)
        ai_provider
      end

      def ai_provider
        @ai_provider ||= OpenAI::Provider.new
      end

      def capabilities
        { ai_provider: ai_provider }
      end
    end
  end
end
