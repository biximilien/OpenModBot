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

    def harassment_interaction_events
      "harassment_interaction_events"
    end

    def harassment_classification_records
      "harassment_classification_records"
    end

    def harassment_classification_jobs
      "harassment_classification_jobs"
    end

    def harassment_classification_cache
      "harassment_classification_cache"
    end

    def harassment_server_rate_limits
      "harassment_server_rate_limits"
    end
  end
end
