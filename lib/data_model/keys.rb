module DataModel
  module Keys
    module_function

    def servers
      "servers"
    end

    def watchlist(server_id)
      "server_#{server_id}_users"
    end

    def karma(server_id)
      "server_#{server_id}_karma"
    end

    def karma_history(server_id, user_id)
      "server_#{server_id}_user_#{user_id}_karma_history"
    end

    def karma_history_pattern(server_id)
      "server_#{server_id}_user_*_karma_history"
    end
  end
end
