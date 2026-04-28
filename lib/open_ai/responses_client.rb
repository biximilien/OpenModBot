require_relative "../../environment"
require_relative "response_parser"

module OpenAI
  class ResponsesClient
    ENDPOINT = "https://api.openai.com/v1/responses".freeze

    def initialize(transport:)
      @transport = transport
    end

    def moderation_rewrite(text, user = nil, instructions:)
      response = @transport.query(ENDPOINT, {
                                    model: Environment.openai_rewrite_model,
                                    instructions: instructions,
                                    input: text,
                                  }, user)

      ResponseParser.text(response)
    end
  end
end
