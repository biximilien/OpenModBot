require "json"
require "time"
require_relative "server_rate_limit_repository"

module Harassment
  module Repositories
    class PostgresServerRateLimitRepository < ServerRateLimitRepository
      def initialize(connection:)
        @connection = connection
      end

      def fetch(server_id)
        row = first_row(
          @connection.exec_params(
            <<~SQL,
              SELECT *
              FROM server_rate_limits
              WHERE guild_id = $1
              LIMIT 1
            SQL
            [server_id.to_s],
          ),
        )
        return [] unless row

        parse_timestamps(row.fetch("timestamps"))
      end

      def save(server_id, timestamps)
        @connection.exec_params(
          <<~SQL,
            INSERT INTO server_rate_limits (
              guild_id,
              timestamps
            )
            VALUES ($1, $2::jsonb)
            ON CONFLICT (guild_id)
            DO UPDATE SET timestamps = EXCLUDED.timestamps
          SQL
          [server_id.to_s, JSON.generate(timestamps.map { |timestamp| timestamp.utc.iso8601 })],
        )
      end

      private

      def parse_timestamps(value)
        parsed =
          case value
          when Array then value
          else JSON.parse(value.to_s)
          end

        parsed.map { |timestamp| Time.parse(timestamp.to_s).utc }
      end

      def first_row(result)
        rows(result).first
      end

      def rows(result)
        result.respond_to?(:to_a) ? result.to_a : Array(result)
      end
    end
  end
end
