module Harassment
  PairRelationshipReport = Data.define(
    :server_id,
    :source_user_id,
    :target_user_id,
    :score_version,
    :relationship_edge,
  ) do
    def self.build(server_id:, source_user_id:, target_user_id:, relationship_edge:)
      new(
        server_id: server_id.to_s,
        source_user_id: source_user_id.to_s,
        target_user_id: target_user_id.to_s,
        score_version: relationship_edge&.score_version,
        relationship_edge: relationship_edge,
      )
    end

    def found?
      !relationship_edge.nil?
    end
  end
end
