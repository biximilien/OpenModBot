module Harassment
  PairRelationshipReport = Data.define(
    :source_user_id,
    :target_user_id,
    :relationship_edge,
  ) do
    def self.build(source_user_id:, target_user_id:, relationship_edge:)
      new(
        source_user_id: source_user_id.to_s,
        target_user_id: target_user_id.to_s,
        relationship_edge: relationship_edge,
      )
    end

    def found?
      !relationship_edge.nil?
    end
  end
end
