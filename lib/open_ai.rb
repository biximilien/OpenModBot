require_relative "../environment"
require_relative "telemetry"
require_relative "open_ai/moderation_client"
require_relative "open_ai/response_parser"
require_relative "open_ai/responses_client"
require_relative "open_ai/transport"

module OpenAI
  DEFAULT_REWRITE_INSTRUCTIONS = "Rewrite the user's message in a direct, neutral tone. State the concern plainly, avoid emotional language, preserve the user's apparent intent, do not add new claims, and return only the rewritten message.".freeze

  ModerationResult = Struct.new(:flagged, :categories, :category_scores, keyword_init: true)

  def query(url, params, user = nil)
    openai_transport.query(url, params, user)
  end

  def moderate_text(text, user = nil)
    ModerationClient.new(transport: self).moderate_text(text, user)
  end

  def moderation_rewrite(text, user = nil, instructions: DEFAULT_REWRITE_INSTRUCTIONS)
    ResponsesClient.new(transport: self).moderation_rewrite(text, user, instructions:)
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
end
