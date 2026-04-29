require_relative "backend"
require_relative "open_ai"

module OpenModBot
  class Application
    include Backend

    attr_writer :ai_provider, :moderation_store

    def initialize(ai_provider: OpenAI::Provider.new, moderation_store: nil)
      @ai_provider = ai_provider
      initialize_backend(store: moderation_store || Moderation::Stores::InMemoryStore.new)
    end

    def moderate_text(text, user = nil)
      ai_provider.moderate_text(text, user)
    end

    def moderation_rewrite(text, user = nil, instructions: OpenModBot::AI::DEFAULT_REWRITE_INSTRUCTIONS)
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
