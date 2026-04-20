require_relative "../environment"
require_relative "moderation/automod_policy"
require_relative "telemetry/anonymizer"

class ModerationStrategy
  def initialize(bot, automod_policy: Moderation::AutomodPolicy.new)
    @bot = bot
    @automod_policy = automod_policy
  end

  def condition(event)
    false
  end

  def execute(event)
    nil
  end

  private

  def record_infraction(event)
    score = @bot.decrement_user_karma(event.server.id, event.user.id)
    user_hash = Telemetry::Anonymizer.hash(event.user.id)
    $logger.info("Karma score for user=#{user_hash}: #{score}")

    if score <= Environment.karma_automod_threshold
      @automod_policy.apply(event, score)
    end

    score
  end
end

class RemoveMessageStrategy < ModerationStrategy
  def condition(event)
    result = @bot.moderate_text(event.message.content, event.user)
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
    $logger.info("Watch list moderation flagged: #{result.flagged}")
    result.flagged
  end

  def execute(event)
    edited = @bot.moderation_rewrite(event.message.content, event.user)
    reason = "Moderation (rewriting due to negative sentiment)"
    event.message.delete(reason)
    record_infraction(event)
    event.respond(response_message(event.user.id, edited))
  end

  private

  def response_message(user_id, edited)
    rewritten = edited.to_s.strip
    return "A message from <@#{user_id}> was removed." if rewritten.empty?

    "A message from <@#{user_id}> was rewritten:\n#{rewritten}"
  end
end
