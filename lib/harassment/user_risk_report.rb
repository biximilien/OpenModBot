module Harassment
  UserRiskReport = Data.define(
    :server_id,
    :user_id,
    :score_version,
    :risk_score,
    :relationship_count,
    :signals,
  ) do
    def self.build(server_id:, user_id:, score_version:, risk_score:, relationship_count:, signals: {})
      new(
        server_id: server_id.to_s,
        user_id: user_id.to_s,
        score_version: score_version.to_s,
        risk_score: Float(risk_score),
        relationship_count: Integer(relationship_count),
        signals: symbolize_numeric_hash(signals),
      )
    end

    class << self
      private

      def symbolize_numeric_hash(signals)
        Hash(signals).transform_keys(&:to_sym).transform_values { |value| Float(value) }
      end
    end
  end
end
