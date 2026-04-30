module Moderation
  module Stores
    module Postgres
      module ServerStore
        def add_server(server_id)
          exec(<<~SQL, [server_id.to_s])
            INSERT INTO moderation_servers (guild_id)
            VALUES ($1)
            ON CONFLICT DO NOTHING
          SQL
        end

        def remove_server(server_id)
          normalized_server_id = server_id.to_s
          exec("DELETE FROM moderation_servers WHERE guild_id = $1", [normalized_server_id])
          exec("DELETE FROM moderation_watchlist WHERE guild_id = $1", [normalized_server_id])
          exec("DELETE FROM moderation_karma WHERE guild_id = $1", [normalized_server_id])
          exec("DELETE FROM moderation_karma_events WHERE guild_id = $1", [normalized_server_id])
          exec("DELETE FROM moderation_reviews WHERE guild_id = $1", [normalized_server_id])
        end

        def servers
          rows(exec("SELECT guild_id FROM moderation_servers ORDER BY guild_id", [])).map do |row|
            row.fetch("guild_id").to_i
          end
        end
      end
    end
  end
end
