require_relative "../../environment"

module OpenAI
  class ModerationClient
    ENDPOINT = "https://api.openai.com/v1/moderations".freeze

    def initialize(transport:)
      @transport = transport
    end

    def moderate_text(text, user = nil)
      response = @transport.query(ENDPOINT, {
                                    model: Environment.openai_moderation_model,
                                    input: text,
                                  }, user)

      result = response.fetch("results").first
      ModerationResult.new(
        flagged: result.fetch("flagged"),
        categories: result.fetch("categories"),
        category_scores: result.fetch("category_scores"),
      )
    end
  end
end
