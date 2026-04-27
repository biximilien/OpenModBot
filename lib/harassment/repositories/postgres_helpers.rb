require "json"
require_relative "../classifier/version"

module Harassment
  module Repositories
    module PostgresHelpers
      private

      def first_row(result)
        rows(result).first
      end

      def rows(result)
        result.respond_to?(:to_a) ? result.to_a : Array(result)
      end

      def parse_json_value(value)
        case value
        when Hash, Array then value
        else JSON.parse(value.to_s)
        end
      end

      def deep_symbolize(value)
        case value
        when Hash
          value.each_with_object({}) { |(key, nested), result| result[key.to_sym] = deep_symbolize(nested) }
        when Array
          value.map { |item| deep_symbolize(item) }
        else
          value
        end
      end

      def normalize_classifier_version(classifier_version)
        case classifier_version
        when ClassifierVersion then classifier_version.value
        else ClassifierVersion.build(classifier_version).value
        end
      end
    end
  end
end
