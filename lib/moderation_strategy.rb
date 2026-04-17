class ModerationStrategy
  def initialize(bot)
    @bot = bot
  end

  def condition(event)
    false
  end

  def execute(event)
    nil
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
    $logger.info(edited)
    reason = "Moderation (rewriting due to negative sentiment)"
    event.message.delete(reason)
    event.respond("~~<@#{event.user.id}>: #{event.message.content}~~" + "\n" + edited)
  end
end
