require_relative "../environment"
require_relative "ai/defaults"
require_relative "ai/moderation_result"
require_relative "ai/provider"
require_relative "telemetry"
require_relative "open_ai/moderation_client"
require_relative "open_ai/response_parser"
require_relative "open_ai/responses_client"
require_relative "open_ai/transport"

module OpenAI
  DEFAULT_REWRITE_INSTRUCTIONS = OpenModBot::AI::DEFAULT_REWRITE_INSTRUCTIONS

  ModerationResult = OpenModBot::AI::ModerationResult
  RESPONSES_ENDPOINT = "https://api.openai.com/v1/responses".freeze

  def query(url, params, user = nil)
    openai_transport.query(url, params, user)
  end

  def moderate_text(text, user = nil)
    ModerationClient.new(transport: self).moderate_text(text, user)
  end

  def moderation_rewrite(text, user = nil, instructions: DEFAULT_REWRITE_INSTRUCTIONS)
    ResponsesClient.new(transport: self).moderation_rewrite(text, user, instructions:)
  end

  def generate_structured(prompt:, schema:, model: nil, instructions: nil, schema_name: nil, user: nil)
    query(
      RESPONSES_ENDPOINT,
      {
        model: model || Environment.harassment_classifier_model,
        instructions: instructions,
        input: prompt,
        text: {
          format: {
            type: "json_schema",
            name: schema_name || "structured_output",
            strict: true,
            schema: schema
          }
        }
      },
      user
    )
  end

  def response_text(response)
    ResponseParser.text(response)
  end

  def anonymized_user_hash(user)
    return nil unless user

    Telemetry::Anonymizer.hash(user.id)
  end

  def openai_transport
    @openai_transport ||= Transport.new
  end

  class Provider < OpenModBot::AI::Provider
    include OpenAI
  end
end
