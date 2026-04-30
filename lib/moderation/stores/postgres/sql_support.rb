require "json"

module Moderation
  module Stores
    module Postgres
      module SqlSupport
        private

        def exec(sql, params)
          @connection.exec_params(sql, params)
        end

        def first_row(result)
          rows(result).first
        end

        def rows(result)
          result.respond_to?(:to_a) ? result.to_a : Array(result)
        end

        def parse_json_hash(value)
          parsed = value.is_a?(Hash) ? value : JSON.parse(value.to_s)
          parsed.transform_keys(&:to_sym)
        end

        def optional_postgres_bool(value)
          return nil if value.nil?

          pg_value?(value)
        end

        def pg_value?(value)
          value == true || value.to_s == "t" || value.to_s == "true"
        end
      end
    end
  end
end
