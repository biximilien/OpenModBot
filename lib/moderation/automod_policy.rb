require "discordrb/api"
require "time"
require_relative "../../environment"
require_relative "automod_outcome"
require_relative "../telemetry/anonymizer"

module Moderation
  class AutomodPolicy
    VALID_ACTIONS = %w[log_only timeout kick ban].freeze

    def initialize(
      action: Environment.karma_automod_action,
      timeout_seconds: Environment.karma_timeout_seconds
    )
      @action = VALID_ACTIONS.include?(action) ? action : Environment::DEFAULT_KARMA_AUTOMOD_ACTION
      @timeout_seconds = timeout_seconds
    end

    def apply(event, score)
      user_hash = Telemetry::Anonymizer.hash(event.user.id)
      if @action != "log_only" && protected_member?(event)
        $logger.warn("User #{user_hash} reached automated moderation threshold with karma #{score}, but has elevated permissions")
        return AutomodOutcome::SKIPPED_ELEVATED_MEMBER
      end

      case @action
      when "log_only" then log_only(user_hash, score)
      when "timeout" then timeout(event, user_hash, score)
      when "kick" then kick(event, user_hash, score)
      when "ban" then ban(event, user_hash, score)
      end
    end

    private

    def log_only(user_hash, score)
      $logger.warn("User #{user_hash} reached automated moderation threshold with karma #{score}")
      AutomodOutcome::LOG_ONLY
    end

    def timeout(event, user_hash, score)
      target = moderation_target(event)
      reason = moderation_reason(score)

      return applied_or_unavailable(user_hash, score, "timeout", AutomodOutcome::TIMEOUT_APPLIED, AutomodOutcome::TIMEOUT_UNAVAILABLE) do
        if target.respond_to?(:timeout_for)
          target.timeout_for(@timeout_seconds, reason)
        elsif target.respond_to?(:timeout)
          target.timeout(@timeout_seconds, reason)
        else
          timeout_via_api(event, reason)
        end
      end
    end

  def kick(event, user_hash, score)
    target = moderation_target(event)
    reason = moderation_reason(score)

    applied_or_unavailable(user_hash, score, "kick", AutomodOutcome::KICK_APPLIED, AutomodOutcome::KICK_UNAVAILABLE) do
      if target.respond_to?(:kick)
        target.kick(reason)
        true
      elsif event.server.respond_to?(:kick)
        event.server.kick(event.user, reason)
        true
      else
        false
      end
    end
  end

  def ban(event, user_hash, score)
    target = moderation_target(event)
    reason = moderation_reason(score)

    applied_or_unavailable(user_hash, score, "ban", AutomodOutcome::BAN_APPLIED, AutomodOutcome::BAN_UNAVAILABLE) do
      if target.respond_to?(:ban)
        target.ban(reason)
        true
      elsif event.server.respond_to?(:ban)
        event.server.ban(event.user, 0, reason: reason)
        true
      else
        false
      end
    end
  end

    def moderation_target(event)
      return event.member if event.respond_to?(:member) && event.member
      return event.server.member(event.user.id) if event.server.respond_to?(:member)

      event.user
    end

    def protected_member?(event)
      target = moderation_target(event)
      return false unless target.respond_to?(:permission?)

      %i[administrator manage_messages moderate_members kick_members ban_members].any? do |permission|
        target.permission?(permission)
      end
    end

    def moderation_reason(score)
      "Automated moderation: karma #{score}"
    end

    def applied_or_unavailable(user_hash, score, action_name, applied_outcome, unavailable_outcome)
      return applied_outcome if yield

      $logger.warn("User #{user_hash} reached #{action_name} threshold with karma #{score}, but #{action_name} is unavailable")
      unavailable_outcome
    end

    def timeout_via_api(event, reason)
      token = event.server.instance_variable_get(:@bot)&.token
      return false unless token

      Discordrb::API.request(
        :guilds_sid_members_uid,
        event.server.id,
        :patch,
        "#{Discordrb::API.api_base}/guilds/#{event.server.id}/members/#{event.user.id}",
        { communication_disabled_until: (Time.now.utc + @timeout_seconds).iso8601 }.to_json,
        Authorization: token,
        content_type: :json,
        "X-Audit-Log-Reason": reason,
      )
      true
    end
  end
end
