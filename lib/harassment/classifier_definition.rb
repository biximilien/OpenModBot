require_relative "open_ai_classifier"
require_relative "../../environment"

module Harassment
  class ClassifierDefinition
    INTENTS = %w[neutral friendly teasing aggressive abusive threatening].freeze
    TARGET_TYPES = %w[individual group self none].freeze
    TOXICITY_DIMENSIONS = %w[insult threat profanity exclusion harassment].freeze
    CLASSIFIER_VERSION = "harassment-v1".freeze
    PROMPT_VERSION = "harassment-prompt-v1".freeze
    SCHEMA_NAME = "harassment_classification".freeze
    RESPONSE_SCHEMA = {
      type: "object",
      additionalProperties: false,
      required: %w[intent target_type toxicity_dimensions severity_score confidence],
      properties: {
        intent: {
          type: "string",
          enum: INTENTS,
        },
        target_type: {
          type: "string",
          enum: TARGET_TYPES,
        },
        toxicity_dimensions: {
          type: "object",
          additionalProperties: false,
          required: TOXICITY_DIMENSIONS,
          properties: TOXICITY_DIMENSIONS.to_h { |dimension| [dimension, { type: "boolean" }] },
        },
        severity_score: {
          type: "number",
          minimum: 0.0,
          maximum: 1.0,
        },
        confidence: {
          type: "number",
          minimum: 0.0,
          maximum: 1.0,
        },
      },
    }.freeze
    INSTRUCTIONS = <<~TEXT.freeze
      Classify a Discord moderation event for harassment analysis.
      Return only structured JSON that matches the supplied schema.
      Use the message content and target metadata to infer:
      - intent
      - target_type
      - toxicity_dimensions
      - severity_score
      - confidence
      Do not recommend punishment or policy actions.
      Treat this as semantic labeling only.
    TEXT

    def classifier_version
      CLASSIFIER_VERSION
    end

    def prompt_version
      PROMPT_VERSION
    end

    def build(client:, model: Environment.harassment_classifier_model)
      OpenAIClassifier.new(
        client: client,
        model: model,
        instructions: INSTRUCTIONS,
        schema_name: SCHEMA_NAME,
        response_schema: RESPONSE_SCHEMA,
        prompt_version: prompt_version,
      )
    end
  end
end
