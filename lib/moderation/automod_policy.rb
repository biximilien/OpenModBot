require "discordrb/api"
require "time"
require_relative "../../environment"
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
    end

    def timeout(event, user_hash, score)
      target = moderation_target(event)
      reason = moderation_reason(score)

      if target.respond_to?(:timeout_for)
        target.timeout_for(@timeout_seconds, reason)
      elsif target.respond_to?(:timeout)
        target.timeout(@timeout_seconds, reason)
      elsif timeout_via_api(event, reason)
        true
      else
        $logger.warn("User #{user_hash} reached timeout threshold with karma #{score}, but timeout is unavailable")
      end
    end

    def kick(event, user_hash, score)
      target = moderation_target(event)

      if target.respond_to?(:kick)
        target.kick(moderation_reason(score))
      elsif event.server.respond_to?(:kick)
        event.server.kick(event.user, moderation_reason(score))
      else
        $logger.warn("User #{user_hash} reached kick threshold with karma #{score}, but kick is unavailable")
      end
    end

    def ban(event, user_hash, score)
      target = moderation_target(event)

      if target.respond_to?(:ban)
        target.ban(moderation_reason(score))
      elsif event.server.respond_to?(:ban)
        event.server.ban(event.user, 0, reason: moderation_reason(score))
      else
        $logger.warn("User #{user_hash} reached ban threshold with karma #{score}, but ban is unavailable")
      end
    end

    def moderation_target(event)
      return event.member if event.respond_to?(:member) && event.member
      return event.server.member(event.user.id) if event.server.respond_to?(:member)

      event.user
    end

    def moderation_reason(score)
      "Automated moderation: karma #{score}"
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
