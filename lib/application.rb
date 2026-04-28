require_relative "backend"
require_relative "open_ai"

module ModerationGPT
  class Application
    include Backend

    attr_writer :ai_provider

    def initialize(ai_provider: OpenAI::Provider.new)
      @ai_provider = ai_provider
      initialize_backend
    end

    def moderate_text(text, user = nil)
      ai_provider.moderate_text(text, user)
    end

    def moderation_rewrite(text, user = nil, instructions: ModerationGPT::AI::DEFAULT_REWRITE_INSTRUCTIONS)
      ai_provider.moderation_rewrite(text, user, instructions:)
    end

    def query(url, params, user = nil)
      ai_provider.query(url, params, user)
    end

    def response_text(response)
      ai_provider.response_text(response)
    end

    def ai_provider
      @ai_provider ||= OpenAI::Provider.new
    end
  end
end
