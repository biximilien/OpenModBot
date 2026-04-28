require_relative "../../environment"
require_relative "../ai/json_transport"

module OpenAI
  class Transport
    def initialize(api_key: Environment.openai_api_key)
      @transport = ModerationGPT::AI::JsonTransport.new(
        provider_name: "OpenAI",
        headers: {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{api_key}",
        },
      )
    end

    def query(url, params, user = nil)
      @transport.post(url:, payload: params, user:)
    end
  end
end
