require "json"
require_relative "../../environment"
require_relative "../ai/defaults"
require_relative "../ai/moderation_result"
require_relative "../ai/provider"
require_relative "response_parser"
require_relative "transport"

module GoogleAI
  class Provider < ModerationGPT::AI::Provider
    DEFAULT_REWRITE_INSTRUCTIONS = ModerationGPT::AI::DEFAULT_REWRITE_INSTRUCTIONS
    MODERATION_SCHEMA = {
      type: "object",
      additionalProperties: false,
      required: %w[flagged categories category_scores],
      properties: {
        flagged: { type: "boolean" },
        categories: {
          type: "object",
          additionalProperties: false,
          required: %w[harassment hate threat sexual violence self_harm],
          properties: %w[harassment hate threat sexual violence self_harm].to_h { |name| [name, { type: "boolean" }] },
        },
        category_scores: {
          type: "object",
          additionalProperties: false,
          required: %w[harassment hate threat sexual violence self_harm],
          properties: %w[harassment hate threat sexual violence self_harm].to_h { |name| [name, { type: "number", minimum: 0.0, maximum: 1.0 }] },
        },
      },
    }.freeze

    def initialize(transport: Transport.new, model: Environment.google_ai_model)
      super()
      @transport = transport
      @model = model
    end

    def moderate_text(text, user = nil)
      response = generate_json(
        prompt: [
          "Classify this Discord message for moderation review.",
          "Return only JSON matching the schema.",
          "Message:",
          text,
        ].join("\n"),
        schema: MODERATION_SCHEMA,
        user:,
      )
      payload = JSON.parse(response_text(response))

      ModerationGPT::AI::ModerationResult.new(
        flagged: payload.fetch("flagged"),
        categories: payload.fetch("categories"),
        category_scores: payload.fetch("category_scores"),
      )
    end

    def moderation_rewrite(text, user = nil, instructions: DEFAULT_REWRITE_INSTRUCTIONS)
      response = generate_text(
        prompt: "#{instructions}\n\nMessage:\n#{text}",
        user:,
      )
      response_text(response)
    end

    def query(_url, params, user = nil)
      schema = params.dig(:text, :format, :schema) || params.dig("text", "format", "schema")
      instructions = params[:instructions] || params["instructions"]
      input = params[:input] || params["input"]
      model = params[:model] || params["model"] || @model

      if schema
        generate_structured(prompt: input, schema:, instructions:, user:, model:)
      else
        generate_text(prompt: [instructions, input].compact.join("\n\n"), user:, model:)
      end
    end

    def generate_structured(prompt:, schema:, model: nil, instructions: nil, _schema_name: nil, user: nil)
      generate_json(prompt: [instructions, prompt].compact.join("\n\n"), schema:, user:, model: model || @model)
    end

    def response_text(response)
      ResponseParser.text(response)
    end

    private

    def generate_text(prompt:, user:, model: @model)
      @transport.generate_content(
        model:,
        payload: content_payload(prompt),
        user:,
      )
    end

    def generate_json(prompt:, schema:, user:, model: @model)
      @transport.generate_content(
        model:,
        payload: content_payload(prompt).merge(
          generationConfig: {
            responseMimeType: "application/json",
            responseJsonSchema: normalize_schema(schema),
          },
        ),
        user:,
      )
    end

    def content_payload(prompt)
      {
        contents: [
          {
            parts: [
              { text: prompt.to_s },
            ],
          },
        ],
      }
    end

    def normalize_schema(schema)
      case schema
      when Hash
        schema.each_with_object({}) do |(key, value), normalized|
          normalized[key.to_s] = normalize_schema(value)
        end
      when Array
        schema.map { |value| normalize_schema(value) }
      else
        schema
      end
    end
  end
end
