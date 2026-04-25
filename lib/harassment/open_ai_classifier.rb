require "json"
require_relative "classification_record"
require_relative "classifier"
require_relative "../../environment"

module Harassment
  class OpenAIClassifier < Classifier
    INTENTS = %w[neutral friendly teasing aggressive abusive threatening].freeze
    TARGET_TYPES = %w[individual group self none].freeze
    TOXICITY_DIMENSIONS = %w[insult threat profanity exclusion harassment].freeze

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

    def initialize(client:, model: Environment.harassment_classifier_model)
      @client = client
      @model = model
    end

    def classify(event:, classifier_version:, context: nil, classified_at: Time.now.utc)
      response = @client.query(
        "https://api.openai.com/v1/responses",
        {
          model: @model,
          instructions: INSTRUCTIONS,
          input: classifier_input(event, context: context),
          text: {
            format: {
              type: "json_schema",
              name: "harassment_classification",
              strict: true,
              schema: RESPONSE_SCHEMA,
            },
          },
        },
      )

      payload = parse_response_payload(response)

      ClassificationRecord.build(
        message_id: event.message_id,
        classifier_version: classifier_version,
        classification: {
          intent: payload.fetch(:intent),
          target_type: payload.fetch(:target_type),
          toxicity_dimensions: payload.fetch(:toxicity_dimensions),
        },
        severity_score: payload.fetch(:severity_score),
        confidence: payload.fetch(:confidence),
        classified_at: classified_at,
      )
    end

    private

    def classifier_input(event, context:)
      participant_labels = (context || {}).fetch(:participant_labels, {})

      {
        message: {
          timestamp: event.timestamp.iso8601,
          content: event.raw_content,
          author_label: participant_labels.fetch(event.author_id, "author"),
          target_labels: event.target_user_ids.map { |target_user_id| participant_labels.fetch(target_user_id, "target") },
        },
        recent_channel_messages: Array((context || {})[:recent_channel_messages]),
        recent_pair_interactions: Array((context || {})[:recent_pair_interactions]),
      }.to_json
    end

    def parse_response_payload(response)
      output = @client.response_text(response)
      raise ArgumentError, "OpenAI harassment classifier returned no structured output" if output.nil? || output.strip.empty?

      JSON.parse(output, symbolize_names: true)
    rescue JSON::ParserError => e
      raise ArgumentError, "OpenAI harassment classifier returned invalid JSON: #{e.message}"
    end
  end
end
