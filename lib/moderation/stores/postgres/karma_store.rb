module Moderation
  module Stores
    module Postgres
      module KarmaStore
        def get_user_karma(server_id, user_id)
          row = first_row(exec(
                            "SELECT score FROM moderation_karma WHERE guild_id = $1 AND user_id = $2 LIMIT 1",
                            [server_id.to_s, user_id.to_s]
                          ))
          row ? row.fetch("score").to_i : 0
        end

        def decrement_user_karma(
          server_id, user_id, amount = 1, source: "automated_infraction", actor_id: nil, reason: nil
        )
          validated_amount = positive_integer!(amount, "amount")
          change_user_karma(server_id, user_id, -validated_amount, source:, actor_id:, reason:)
        end

        def increment_user_karma(
          server_id, user_id, amount = 1, source: "manual_adjustment", actor_id: nil, reason: nil
        )
          validated_amount = positive_integer!(amount, "amount")
          change_user_karma(server_id, user_id, validated_amount, source:, actor_id:, reason:)
        end

        def set_user_karma(server_id, user_id, score, source: "manual_reset", actor_id: nil, reason: nil)
          validated_score = integer!(score, "score")
          previous_score = get_user_karma(server_id, user_id)
          write_user_karma(server_id, user_id, validated_score)
          record_user_karma_event(
            server_id,
            user_id,
            score: validated_score,
            delta: validated_score - previous_score,
            source:,
            actor_id:,
            reason:
          )
          validated_score
        end

        def record_user_karma_event(server_id, user_id, score:, source:, delta: 0, actor_id: nil, reason: nil)
          event = build_karma_event(score:, delta:, source:, actor_id:, reason:)
          exec(<<~SQL, karma_event_insert_params(server_id, user_id, event))
            INSERT INTO moderation_karma_events (guild_id, user_id, delta, score, source, actor_id, reason, created_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
          SQL
          event.to_h.compact
        end

        def get_user_karma_history(server_id, user_id, limit = 5)
          history_limit = limit.to_i.clamp(1, StoreSupport::KARMA_AUDIT_LIMIT)
          rows(exec(<<~SQL, [server_id.to_s, user_id.to_s, history_limit]))
            SELECT delta, score, source, actor_id, reason, created_at
            FROM moderation_karma_events
            WHERE guild_id = $1 AND user_id = $2
            ORDER BY created_at DESC, id DESC
            LIMIT $3
          SQL
            .map { |row| karma_event_from_row(row).to_h.compact }
        end

        private

        def change_user_karma(server_id, user_id, delta, source:, actor_id:, reason:)
          score = get_user_karma(server_id, user_id) + delta
          write_user_karma(server_id, user_id, score)
          record_user_karma_event(server_id, user_id, score:, delta:, source:, actor_id:, reason:)
          score
        end

        def write_user_karma(server_id, user_id, score)
          exec(<<~SQL, [server_id.to_s, user_id.to_s, score])
            INSERT INTO moderation_karma (guild_id, user_id, score)
            VALUES ($1, $2, $3)
            ON CONFLICT (guild_id, user_id)
            DO UPDATE SET score = EXCLUDED.score
          SQL
        end

        def karma_event_insert_params(server_id, user_id, event)
          [
            server_id.to_s,
            user_id.to_s,
            event.delta,
            event.score,
            event.source,
            event.actor_id&.to_s,
            event.reason,
            event.created_at
          ]
        end

        def karma_event_from_row(row)
          DataModel::KarmaEvent.new(
            created_at: row.fetch("created_at").to_s,
            delta: row.fetch("delta").to_i,
            score: row.fetch("score").to_i,
            source: row.fetch("source"),
            actor_id: optional_integer(row["actor_id"]),
            reason: row["reason"]
          )
        end
      end
    end
  end
end
