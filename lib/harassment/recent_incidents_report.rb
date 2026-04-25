module Harassment
  RecentIncidentsReport = Data.define(
    :channel_id,
    :user_id,
    :incidents,
  ) do
    def self.build(channel_id:, incidents:, user_id: nil)
      new(
        channel_id: channel_id.to_s,
        user_id: user_id&.to_s,
        incidents: Array(incidents),
      )
    end
  end
end
