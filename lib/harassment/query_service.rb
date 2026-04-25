require_relative "pair_relationship_report"
require_relative "recent_incidents_report"
require_relative "user_risk_report"

module Harassment
  class QueryService
    def initialize(read_model:)
      @read_model = read_model
    end

    def get_user_risk(user_id)
      normalized_user_id = user_id.to_s
      edges = @read_model.outgoing_relationships(normalized_user_id)

      UserRiskReport.build(
        user_id: normalized_user_id,
        risk_score: edges.sum(&:hostility_score),
        relationship_count: edges.length,
      )
    end

    def get_pair_relationship(user_a, user_b)
      PairRelationshipReport.build(
        source_user_id: user_a,
        target_user_id: user_b,
        relationship_edge: @read_model.get_pair_relationship(user_a, user_b),
      )
    end

    def recent_incidents(channel_id, limit: 10)
      RecentIncidentsReport.build(
        channel_id: channel_id,
        incidents: @read_model.recent_incidents(channel_id, limit:),
      )
    end
  end
end
