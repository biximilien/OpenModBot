require "json"
require_relative "../classification/record"
require_relative "classifier"

module Harassment
  class StructuredClassifier < Classifier
    def initialize(client:, model:, instructions:, schema_name:, response_schema:, prompt_version:)
      @client = client
      @model = model
      @instructions = instructions
      @schema_name = schema_name
      @response_schema = response_schema
      @prompt_version = prompt_version
    end

    def classify(event:, classifier_version:, context: nil, classified_at: Time.now.utc)
      response = @client.generate_structured(
        model: @model,
        instructions: @instructions,
        prompt: classifier_input(event, context: context),
        schema_name: @schema_name,
        schema: @response_schema,
      )

      payload = parse_response_payload(response)
      classification, severity_score, confidence = validated_payload(payload)

      ClassificationRecord.build(
        server_id: event.server_id,
        message_id: event.message_id,
        classifier_version: classifier_version,
        model_version: @model,
        prompt_version: @prompt_version,
        classification: classification,
        severity_score: severity_score,
        confidence: confidence,
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
      raise ClassifierOutputError, "Structured harassment classifier returned no output" if output.nil? || output.strip.empty?

      JSON.parse(output, symbolize_names: true)
    rescue JSON::ParserError => e
      raise ClassifierOutputError, "Structured harassment classifier returned invalid JSON: #{e.message}"
    end

    def validated_payload(payload)
      classification = {
        intent: payload.fetch(:intent),
        target_type: payload.fetch(:target_type),
        toxicity_dimensions: output_hash(payload.fetch(:toxicity_dimensions), "toxicity_dimensions"),
      }

      [
        classification,
        bounded_output_float(payload.fetch(:severity_score), "severity_score"),
        bounded_output_float(payload.fetch(:confidence), "confidence"),
      ]
    rescue KeyError => e
      raise ClassifierOutputError, "Structured harassment classifier output failed validation: missing #{e.key}"
    end

    def bounded_output_float(value, name)
      numeric = Float(value)
      raise ClassifierOutputError, "Structured harassment classifier output failed validation: #{name} must be between 0.0 and 1.0" unless numeric.between?(0.0, 1.0)

      numeric
    rescue ArgumentError, TypeError
      raise ClassifierOutputError, "Structured harassment classifier output failed validation: #{name} must be between 0.0 and 1.0"
    end

    def output_hash(value, name)
      return value if value.is_a?(Hash)

      raise ClassifierOutputError, "Structured harassment classifier output failed validation: #{name} must be an object"
    end
  end
end
