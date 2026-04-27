require "json"

module Harassment
  module PostgresVerificationHelpers
    private

    def rows(result)
      result.respond_to?(:to_a) ? result.to_a : Array(result)
    end

    def first_row(result)
      rows(result).first || {}
    end

    def redis_rows_for(redis, key)
      redis.hgetall(key).values.map { |payload| JSON.parse(payload) }
    end

    def build_spot_check_summary(source_rows)
      mismatches = []
      matched = 0

      source_rows.each do |data|
        row_matched, details = yield(data)
        if row_matched
          matched += 1
        else
          mismatches << details
        end
      end

      {
        sampled: source_rows.length,
        matched:,
        mismatches:,
        matches: mismatches.empty?,
      }
    end

    def compare_record(identifier:, expected:, actual:)
      return [true, nil] if expected == actual

      [false, identifier.merge(fields: mismatch_fields(expected:, actual:))]
    end

    def build_known_verification_result(expected:, actual:, identifier: nil)
      result = {
        found_in_redis: true,
        found_in_postgres: true,
        matches: expected == actual,
      }
      result[:identifier] = identifier if identifier
      result[:fields] = mismatch_fields(expected:, actual:) unless expected == actual
      result
    end

    def missing_known_result(identifier)
      {
        found_in_redis: true,
        found_in_postgres: false,
        matches: false,
        identifier:,
      }
    end

    def mismatch_fields(expected:, actual:)
      expected.each_with_object({}) do |(field, expected_value), mismatches|
        actual_value = actual.fetch(field)
        next if actual_value == expected_value

        mismatches[field] = { expected: expected_value, actual: actual_value }
      end
    end
  end
end
