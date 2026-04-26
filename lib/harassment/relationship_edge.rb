require "time"

module Harassment
  RelationshipEdge = Data.define(
    :server_id,
    :source_user_id,
    :target_user_id,
    :score_version,
    :hostility_score,
    :positive_score,
    :interaction_count,
    :last_interaction_at,
  ) do
    def self.build(
      server_id:,
      source_user_id:,
      target_user_id:,
      score_version:,
      hostility_score: 0.0,
      positive_score: 0.0,
      interaction_count: 0,
      last_interaction_at: nil
    )
      new(
        server_id: identifier!(server_id, "server_id"),
        source_user_id: identifier!(source_user_id, "source_user_id"),
        target_user_id: identifier!(target_user_id, "target_user_id"),
        score_version: identifier!(score_version, "score_version"),
        hostility_score: non_negative_float!(hostility_score, "hostility_score"),
        positive_score: non_negative_float!(positive_score, "positive_score"),
        interaction_count: non_negative_integer!(interaction_count, "interaction_count"),
        last_interaction_at: optional_time(last_interaction_at, "last_interaction_at"),
      )
    end

    def decay_to(as_of:, decay_policy:)
      self.class.build(
        server_id: server_id,
        source_user_id: source_user_id,
        target_user_id: target_user_id,
        score_version: score_version,
        hostility_score: decay_policy.decay(hostility_score, from: last_interaction_at, to: as_of),
        positive_score: decay_policy.decay(positive_score, from: last_interaction_at, to: as_of),
        interaction_count: interaction_count,
        last_interaction_at: last_interaction_at,
      )
    end

    class << self
      private

      def identifier!(value, name)
        normalized = value.to_s.strip
        raise ArgumentError, "#{name} must not be empty" if normalized.empty?

        normalized
      end

      def non_negative_float!(value, name)
        numeric = Float(value)
        raise ArgumentError, "#{name} must be non-negative" if numeric.negative?

        numeric
      rescue ArgumentError, TypeError
        raise ArgumentError, "#{name} must be non-negative"
      end

      def non_negative_integer!(value, name)
        integer = Integer(value)
        raise ArgumentError, "#{name} must be non-negative" if integer.negative?

        integer
      rescue ArgumentError, TypeError
        raise ArgumentError, "#{name} must be non-negative"
      end

      def optional_time(value, name)
        return nil if value.nil?

        case value
        when Time then value.utc
        else
          Time.parse(value.to_s).utc
        end
      rescue ArgumentError
        raise ArgumentError, "#{name} must be a valid time"
      end
    end
  end
end
