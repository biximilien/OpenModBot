module Harassment
  class ServerRateLimiter
    WINDOW_SECONDS = 60

    def initialize(repository:, limit_per_minute:)
      @repository = repository
      @limit_per_minute = Integer(limit_per_minute)
    end

    def reserve(server_id, at: Time.now.utc)
      return nil if @limit_per_minute <= 0

      timestamps = recent_timestamps(server_id, at)
      if timestamps.length < @limit_per_minute
        timestamps << at.utc
        @repository.save(server_id, timestamps)
        nil
      else
        @repository.save(server_id, timestamps)
        timestamps.first + WINDOW_SECONDS
      end
    end

    private

    def recent_timestamps(server_id, at)
      cutoff = at.utc - WINDOW_SECONDS
      @repository.fetch(server_id).map(&:utc).select { |timestamp| timestamp > cutoff }.sort
    end
  end
end
