require_relative "../environment"
require_relative "moderation/automod_policy"
require_relative "telemetry/anonymizer"

class ModerationStrategy
  def initialize(bot, automod_policy: Moderation::AutomodPolicy.new, plugin_registry: nil)
    @bot = bot
    @automod_policy = automod_policy
    @plugin_registry = plugin_registry
  end

  def condition(event)
    false
  end

  def execute(event)
    nil
  end

  private

  def record_infraction(event)
    previous_score = @bot.get_user_karma(event.server.id, event.user.id)
    score = @bot.decrement_user_karma(event.server.id, event.user.id)
    user_hash = Telemetry::Anonymizer.hash(event.user.id)
    $logger.info("Karma score for user=#{user_hash}: #{score}")
    @plugin_registry&.infraction(event: event, score: score, app: @bot, strategy: self.class.name)

    if crossed_automod_threshold?(previous_score, score)
      automod_outcome = @automod_policy.apply(event, score)
      record_automod_outcome(event, score, automod_outcome)
    end

    score
  end

  def crossed_automod_threshold?(previous_score, score)
    threshold = Environment.karma_automod_threshold
    previous_score > threshold && score <= threshold
  end

  def record_automod_outcome(event, score, outcome)
    return unless outcome

    @bot.record_user_karma_event(event.server.id, event.user.id, score:, source: outcome)
    @plugin_registry&.automod_outcome(event: event, score: score, outcome: outcome, app: @bot, strategy: self.class.name)
  end

  def record_moderation_result(event, result)
    @plugin_registry&.moderation_result(event: event, result: result, app: @bot, strategy: self.class.name)
  end
end

class RemoveMessageStrategy < ModerationStrategy
  def condition(event)
    result = @bot.moderate_text(event.message.content, event.user)
    record_moderation_result(event, result)
    $logger.info("Moderation flagged: #{result.flagged}")
    result.flagged
  end

  def execute(event)
    reason = "Moderation (removing message)"
    event.message.delete(reason)
    record_infraction(event)
  end
end

class WatchListStrategy < ModerationStrategy
  def condition(event)
    return false unless @bot.get_watch_list_users(event.server.id.to_i).include?(event.user.id.to_i)

    result = @bot.moderate_text(event.message.content, event.user)
    record_moderation_result(event, result)
    $logger.info("Watch list moderation flagged: #{result.flagged}")
    result.flagged
  end

  def execute(event)
    edited = moderation_rewrite(event)
    reason = "Moderation (rewriting due to negative sentiment)"
    event.message.delete(reason)
    record_infraction(event)
    event.respond(response_message(event.user.id, edited))
  end

  private

  def moderation_rewrite(event)
    instructions = @plugin_registry&.rewrite_instructions(event: event, app: @bot, strategy: self.class.name)
    return @bot.moderation_rewrite(event.message.content, event.user, instructions:) if instructions

    @bot.moderation_rewrite(event.message.content, event.user)
  end

  def response_message(user_id, edited)
    rewritten = edited.to_s.strip
    return "A message from <@#{user_id}> was removed." if rewritten.empty?

    "A message from <@#{user_id}> was rewritten:\n#{rewritten}"
  end
end
