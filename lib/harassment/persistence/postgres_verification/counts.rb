require "json"
require_relative "../../../data_model/keys"
require_relative "../postgres_verification_helpers"

module Harassment
  module PostgresVerification
    class Counts
      include PostgresVerificationHelpers

      def initialize(redis:, connection:, tables:)
        @redis = redis
        @connection = connection
        @tables = tables
      end

      def run
        @tables.each_with_object({}) do |(name, config), summary|
          redis_counts = redis_counts_for(config.fetch(:redis_key))
          postgres_counts = postgres_counts_for(config.fetch(:table_name))

          summary[name] = {
            redis_total: redis_counts.fetch(:total),
            postgres_total: postgres_counts.fetch(:total),
            redis_by_server: redis_counts.fetch(:by_server),
            postgres_by_server: postgres_counts.fetch(:by_server),
            matches: redis_counts == postgres_counts,
          }
        end
      end

      def postgres_counts_for(table_name)
        total_row = first_row(
          @connection.exec_params(
            <<~SQL,
              SELECT COUNT(*) AS count
              FROM #{table_name}
            SQL
            [],
          ),
        )
        server_rows = rows(
          @connection.exec_params(
            <<~SQL,
              SELECT guild_id, COUNT(*) AS count
              FROM #{table_name}
              GROUP BY guild_id
              ORDER BY guild_id ASC
            SQL
            [],
          ),
        )

        {
          total: total_row.fetch("count").to_i,
          by_server: server_rows.to_h { |row| [row.fetch("guild_id").to_s, row.fetch("count").to_i] },
        }
      end

      private

      def redis_counts_for(key)
        by_server = Hash.new(0)
        redis_rows_for(@redis, key).each do |data|
          by_server[data.fetch("server_id").to_s] += 1
        end

        {
          total: by_server.values.sum,
          by_server: by_server.sort.to_h,
        }
      end
    end
  end
end
