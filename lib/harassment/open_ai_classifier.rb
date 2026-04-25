require "json"
require_relative "classification_record"
require_relative "classifier"

module Harassment
  class OpenAIClassifier < Classifier
    def initialize(client:, model:, instructions:, schema_name:, response_schema:, prompt_version:)
      @client = client
      @model = model
      @instructions = instructions
      @schema_name = schema_name
      @response_schema = response_schema
      @prompt_version = prompt_version
    end

    def classify(event:, classifier_version:, context: nil, classified_at: Time.now.utc)
      response = @client.query(
        "https://api.openai.com/v1/responses",
        {
          model: @model,
          instructions: @instructions,
          input: classifier_input(event, context: context),
          text: {
            format: {
              type: "json_schema",
              name: @schema_name,
              strict: true,
              schema: @response_schema,
            },
          },
        },
      )

      payload = parse_response_payload(response)

      ClassificationRecord.build(
        server_id: event.server_id,
        message_id: event.message_id,
        classifier_version: classifier_version,
        model_version: @model,
        prompt_version: @prompt_version,
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

    def cache_identity
      super.merge(
        model_version: @model,
        prompt_version: @prompt_version,
        schema_name: @schema_name,
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
