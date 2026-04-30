module Moderation
  module Stores
    module Postgres
      module WatchlistStore
        def add_user_to_watch_list(server_id, user_id)
          exec(<<~SQL, [server_id.to_s, user_id.to_s])
            INSERT INTO moderation_watchlist (guild_id, user_id)
            VALUES ($1, $2)
            ON CONFLICT DO NOTHING
          SQL
        end

        def remove_user_from_watch_list(server_id, user_id)
          exec("DELETE FROM moderation_watchlist WHERE guild_id = $1 AND user_id = $2", [server_id.to_s, user_id.to_s])
        end

        def get_watch_list_users(server_id)
          rows(exec("SELECT user_id FROM moderation_watchlist WHERE guild_id = $1 ORDER BY user_id", [server_id.to_s]))
            .map { |row| row.fetch("user_id").to_i }
        end
      end
    end
  end
end
