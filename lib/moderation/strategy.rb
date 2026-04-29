require_relative "../../environment"
require_relative "automod_policy"
require_relative "review_action"
require_relative "../logging"
require_relative "../telemetry/anonymizer"

class ModerationStrategy
  MODERATION_RESULT_CACHE_KEY = :@open_mod_bot_moderation_result

  def initialize(bot, automod_policy: Moderation::AutomodPolicy.new, plugin_registry: nil)
    @bot = bot
    @automod_policy = automod_policy
    @plugin_registry = plugin_registry
  end

  def condition?(_event)
    false
  end

  def execute(_event)
    nil
  end

  private

  def flagged?(event, log_label:)
    result = moderation_result(event)
    Logging.info("moderation_flag_evaluated", strategy: self.class.name, log_label:, flagged: result.flagged)
    result.flagged
  end

  def moderation_result(event)
    if event.instance_variable_defined?(MODERATION_RESULT_CACHE_KEY)
      return event.instance_variable_get(MODERATION_RESULT_CACHE_KEY)
    end

    result = @bot.moderate_text(event.message.content, event.user)
    event.instance_variable_set(MODERATION_RESULT_CACHE_KEY, result)
    record_moderation_result(event, result)
    result
  end

  def record_infraction(event)
    return nil if shadow_mode?

    previous_score = @bot.get_user_karma(event.server.id, event.user.id)
    score = @bot.decrement_user_karma(event.server.id, event.user.id)
    user_hash = Telemetry::Anonymizer.hash(event.user.id)
    Logging.info("karma_score_updated", strategy: self.class.name, user_hash:, karma_score: score, previous_score:)
    @plugin_registry&.infraction(event: event, score: score, app: @bot, strategy: self.class.name)

    if crossed_automod_threshold?(previous_score, score)
      automod_outcome = @automod_policy.apply(event, score)
      record_automod_outcome(event, score, automod_outcome)
      return automod_outcome
    end

    score
  end

  def record_review(event, action:, rewrite: nil, automod_outcome: nil)
    return unless @bot.respond_to?(:record_moderation_review)

    result = cached_moderation_result(event)
    @bot.record_moderation_review(
      server_id: event.server.id,
      channel_id: event.channel.id,
      message_id: event.message.id,
      user_id: event.user.id,
      strategy: self.class.name,
      action: action,
      shadow_mode: shadow_mode?,
      flagged: result&.flagged,
      categories: result&.categories || {},
      category_scores: result&.category_scores || {},
      rewrite: rewrite,
      original_content: review_original_content(event),
      automod_outcome: automod_outcome
    )
  end

  def shadow_mode?
    Environment.moderation_shadow_mode?
  end

  def shadow_rewrite?
    Environment.moderation_shadow_rewrite?
  end

  def outcome_if_automod(value)
    value.is_a?(String) ? value : nil
  end

  def review_original_content(event)
    return nil unless Environment.moderation_review_store_content?

    event.message.content
  end

  def cached_moderation_result(event)
    return nil unless event.instance_variable_defined?(MODERATION_RESULT_CACHE_KEY)

    event.instance_variable_get(MODERATION_RESULT_CACHE_KEY)
  end

  def crossed_automod_threshold?(previous_score, score)
    threshold = Environment.karma_automod_threshold
    previous_score > threshold && score <= threshold
  end

  def record_automod_outcome(event, score, outcome)
    return unless outcome

    @bot.record_user_karma_event(event.server.id, event.user.id, score:, source: outcome)
    @plugin_registry&.automod_outcome(event: event, score: score, outcome: outcome, app: @bot,
                                      strategy: self.class.name)
  end

  def record_moderation_result(event, result)
    @plugin_registry&.moderation_result(event: event, result: result, app: @bot, strategy: self.class.name)
  end
end
