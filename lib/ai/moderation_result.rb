module OpenModBot
  module AI
    ModerationResult = Struct.new(:flagged, :categories, :category_scores, keyword_init: true)
  end
end
