require_relative "composite_signal_analyzer"
require_relative "pair_relationship_report"
require_relative "recent_incidents_report"
require_relative "user_risk_report"

module Harassment
  class QueryService
    def initialize(read_model:, signal_analyzer: CompositeSignalAnalyzer.new(read_model:))
      @read_model = read_model
      @signal_analyzer = signal_analyzer
    end

    def get_user_risk(server_id, user_id, as_of: Time.now.utc)
      normalized_user_id = user_id.to_s
      normalized_server_id = server_id.to_s
      analysis = @signal_analyzer.analyze_user(normalized_server_id, normalized_user_id, as_of:)

      UserRiskReport.build(
        server_id: normalized_server_id,
        user_id: normalized_user_id,
        score_version: analysis.fetch(:score_version),
        risk_score: analysis.fetch(:harassment_score),
        relationship_count: analysis.fetch(:relationship_count),
        signals: analysis.fetch(:signals),
      )
    end

    def get_pair_relationship(server_id, user_a, user_b, as_of: Time.now.utc)
      PairRelationshipReport.build(
        server_id: server_id,
        source_user_id: user_a,
        target_user_id: user_b,
        relationship_edge: @read_model.get_pair_relationship(server_id, user_a, user_b, as_of:),
      )
    end

    def recent_incidents(server_id, channel_id, limit: 10, user_id: nil, since: nil)
      RecentIncidentsReport.build(
        server_id: server_id,
        channel_id: channel_id,
        user_id: user_id,
        since: since,
        incidents: @read_model.recent_incidents(server_id, channel_id, limit:, user_id:, since:),
      )
    end
  end
end
