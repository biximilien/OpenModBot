require_relative "../../environment"
require_relative "../ai/json_transport"

module GoogleAI
  class Transport
    API_ROOT = "https://generativelanguage.googleapis.com/v1beta".freeze

    def initialize(api_key: Environment.google_ai_api_key)
      @transport = ModerationGPT::AI::JsonTransport.new(
        provider_name: "Google AI",
        headers: {
          "Content-Type" => "application/json",
          "x-goog-api-key" => api_key,
        },
      )
    end

    def generate_content(model:, payload:, user: nil)
      url = "#{API_ROOT}/models/#{model}:generateContent"
      @transport.post(url:, payload:, user:)
    end
  end
end
