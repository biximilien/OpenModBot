require "time"
require_relative "classifier_version"

module Harassment
  ClassificationRecord = Data.define(
    :server_id,
    :message_id,
    :classifier_version,
    :model_version,
    :prompt_version,
    :classification,
    :severity_score,
    :confidence,
    :classified_at,
  ) do
    def self.build(
      server_id:,
      message_id:,
      classifier_version:,
      model_version:,
      prompt_version:,
      classification:,
      severity_score:,
      confidence:,
      classified_at: Time.now.utc
    )
      new(
        server_id: identifier!(server_id, "server_id"),
        message_id: identifier!(message_id, "message_id"),
        classifier_version: classifier_version!(classifier_version),
        model_version: identifier!(model_version, "model_version"),
        prompt_version: identifier!(prompt_version, "prompt_version"),
        classification: hash!(classification, "classification"),
        severity_score: bounded_float!(severity_score, "severity_score"),
        confidence: bounded_float!(confidence, "confidence"),
        classified_at: time!(classified_at, "classified_at"),
      )
    end

    class << self
      private

      def identifier!(value, name)
        normalized = value.to_s.strip
        raise ArgumentError, "#{name} must not be empty" if normalized.empty?

        normalized
      end

      def classifier_version!(value)
        value.is_a?(ClassifierVersion) ? value : ClassifierVersion.build(value)
      end

      def hash!(value, name)
        raise ArgumentError, "#{name} must be a hash" unless value.is_a?(Hash)

        value
      end

      def bounded_float!(value, name)
        numeric = Float(value)
        raise ArgumentError, "#{name} must be between 0.0 and 1.0" unless numeric.between?(0.0, 1.0)

        numeric
      rescue ArgumentError, TypeError
        raise ArgumentError, "#{name} must be between 0.0 and 1.0"
      end

      def time!(value, name)
        case value
        when Time then value.utc
        else
          Time.parse(value.to_s).utc
        end
      rescue ArgumentError
        raise ArgumentError, "#{name} must be a valid time"
      end
    end
  end
end
