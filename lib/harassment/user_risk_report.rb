module Harassment
  UserRiskReport = Data.define(
    :user_id,
    :risk_score,
    :relationship_count,
  ) do
    def self.build(user_id:, risk_score:, relationship_count:)
      new(
        user_id: user_id.to_s,
        risk_score: Float(risk_score),
        relationship_count: Integer(relationship_count),
      )
    end
  end
end
