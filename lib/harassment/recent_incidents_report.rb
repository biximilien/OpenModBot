module Harassment
  RecentIncidentsReport = Data.define(
    :channel_id,
    :incidents,
  ) do
    def self.build(channel_id:, incidents:)
      new(
        channel_id: channel_id.to_s,
        incidents: Array(incidents),
      )
    end
  end
end
