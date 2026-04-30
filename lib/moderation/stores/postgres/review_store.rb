require "json"

module Moderation
  module Stores
    module Postgres
      module ReviewStore
        def record_moderation_review(
          server_id:, channel_id:, message_id:, user_id:, strategy:, action:, shadow_mode:, flagged:,
          categories: {}, category_scores: {}, rewrite: nil, original_content: nil, automod_outcome: nil,
          created_at: Time.now.utc
        )
          entry = build_moderation_review_entry(
            server_id:, channel_id:, message_id:, user_id:, strategy:, action:, shadow_mode:, flagged:,
            categories:, category_scores:, rewrite:, original_content:, automod_outcome:, created_at:
          )
          exec(<<~SQL, moderation_review_insert_params(entry))
            INSERT INTO moderation_reviews (
              guild_id, channel_id, message_id, user_id, schema_version, strategy, action, shadow_mode, flagged,
              categories, category_scores, rewrite, original_content, automod_outcome, created_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10::jsonb, $11::jsonb, $12, $13, $14, $15)
          SQL
          entry.to_h
        end

        def get_moderation_reviews(server_id, limit = 5, user_id: nil)
          review_limit = limit.to_i.clamp(1, StoreSupport::MODERATION_REVIEW_LIMIT)
          params = [server_id.to_s, review_limit]
          user_filter = ""
          if user_id
            user_filter = " AND user_id = $3"
            params << user_id.to_s
          end

          rows(exec(<<~SQL, params))
            SELECT schema_version, created_at, guild_id, channel_id, message_id, user_id, strategy, action, shadow_mode,
                   flagged, categories, category_scores, rewrite, original_content, automod_outcome
            FROM moderation_reviews
            WHERE guild_id = $1#{user_filter}
            ORDER BY created_at DESC, id DESC
            LIMIT $2
          SQL
            .map { |row| moderation_review_from_row(row).to_h }
        end

        def find_moderation_review(server_id, message_id)
          get_moderation_reviews(server_id, StoreSupport::MODERATION_REVIEW_LIMIT).find do |entry|
            entry[:message_id] == message_id.to_s
          end
        end

        def clear_moderation_reviews(server_id)
          exec("DELETE FROM moderation_reviews WHERE guild_id = $1", [server_id.to_s])
        end

        private

        def moderation_review_insert_params(entry)
          [
            entry.server_id,
            entry.channel_id,
            entry.message_id,
            entry.user_id,
            entry.schema_version,
            entry.strategy,
            entry.action,
            entry.shadow_mode,
            entry.flagged,
            JSON.generate(entry.categories),
            JSON.generate(entry.category_scores),
            entry.rewrite,
            entry.original_content,
            entry.automod_outcome,
            entry.created_at
          ]
        end

        def moderation_review_from_row(row)
          DataModel::ModerationReviewEntry.new(
            schema_version: row.fetch("schema_version").to_i,
            created_at: row.fetch("created_at").to_s,
            server_id: row.fetch("guild_id"),
            channel_id: row.fetch("channel_id"),
            message_id: row.fetch("message_id"),
            user_id: row.fetch("user_id"),
            strategy: row.fetch("strategy"),
            action: row.fetch("action"),
            shadow_mode: pg_value?(row.fetch("shadow_mode")),
            flagged: optional_postgres_bool(row["flagged"]),
            categories: parse_json_hash(row.fetch("categories")),
            category_scores: parse_json_hash(row.fetch("category_scores")),
            rewrite: row["rewrite"],
            original_content: row["original_content"],
            automod_outcome: row["automod_outcome"]
          )
        end
      end
    end
  end
end
