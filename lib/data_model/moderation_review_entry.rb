require "json"

module DataModel
  ModerationReviewEntry = Struct.new(
    :schema_version,
    :created_at,
    :server_id,
    :channel_id,
    :message_id,
    :user_id,
    :strategy,
    :action,
    :shadow_mode,
    :flagged,
    :categories,
    :category_scores,
    :rewrite,
    :original_content,
    :automod_outcome,
    keyword_init: true,
  ) do
    def to_h
      {
        created_at: created_at,
        schema_version: schema_version,
        server_id: server_id,
        channel_id: channel_id,
        message_id: message_id,
        user_id: user_id,
        strategy: strategy,
        action: action,
        shadow_mode: shadow_mode,
        flagged: flagged,
        categories: categories,
        category_scores: category_scores,
        rewrite: rewrite,
        original_content: original_content,
        automod_outcome: automod_outcome,
      }.compact
    end

    def to_json(*)
      JSON.generate(to_h)
    end

    def self.from_json(payload)
      data = JSON.parse(payload, symbolize_names: true)
      new(**data)
    end
  end
end
