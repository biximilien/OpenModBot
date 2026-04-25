module Harassment
  RecentIncidentsReport = Data.define(
    :server_id,
    :channel_id,
    :user_id,
    :since,
    :incidents,
  ) do
    def self.build(server_id:, channel_id:, incidents:, user_id: nil, since: nil)
      new(
        server_id: server_id.to_s,
        channel_id: channel_id.to_s,
        user_id: user_id&.to_s,
        since: since&.utc,
        incidents: Array(incidents),
      )
    end
  end
end
