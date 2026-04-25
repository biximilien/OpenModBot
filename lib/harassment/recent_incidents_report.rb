module Harassment
  RecentIncidentsReport = Data.define(
    :channel_id,
    :user_id,
    :since,
    :incidents,
  ) do
    def self.build(channel_id:, incidents:, user_id: nil, since: nil)
      new(
        channel_id: channel_id.to_s,
        user_id: user_id&.to_s,
        since: since&.utc,
        incidents: Array(incidents),
      )
    end
  end
end
