require_relative "../../environment"
require_relative "../logging"
require_relative "../plugin"

module OpenModBot
  module Plugins
    class AdminNotificationsPlugin < Plugin
      def initialize(clock: -> { Time.now.utc })
        @clock = clock
        @sent_keys = {}
        @rate_limit_timestamps = Hash.new { |hash, key| hash[key] = [] }
      end

      def boot(bot:, **)
        @discord_bot = bot
        return unless channel_id_missing?

        raise "ADMIN_NOTIFICATION_CHANNEL_ID is required when admin_notifications plugin is enabled"
      end

      def moderation_result(event:, result:, strategy:, **)
        return unless ambiguous?(result)
        return unless notify_once?(:ambiguous_moderation, event)
        return unless rate_limit_allows?(event.server.id)

        deliver(
          notification_message(
            title: "Moderation review needed",
            event: event,
            strategy: strategy,
            details: ["ambiguous_scores=#{score_summary(result)}"]
          )
        )
      end

      def automod_outcome(event:, score:, outcome:, strategy:, **)
        return unless notify_once?(:automod_outcome, event)
        return unless rate_limit_allows?(event.server.id)

        deliver(
          notification_message(
            title: "Automod outcome recorded",
            event: event,
            strategy: strategy,
            details: ["score=#{score}", "outcome=#{outcome}"]
          )
        )
      end

      private

      def channel_id_missing?
        Environment.admin_notification_channel_id.to_s.strip.empty?
      end

      def ambiguous?(result)
        return false unless result
        return false if shadow_mode_suppressed?

        scores = result.category_scores || {}
        scores.any? do |_category, score|
          numeric_score = Float(score)
          numeric_score.between?(min_score, max_score)
        rescue ArgumentError, TypeError
          false
        end
      end

      def shadow_mode_suppressed?
        Environment.moderation_shadow_mode? && !Environment.admin_notification_shadow_mode?
      end

      def min_score
        Environment.admin_notification_ambiguous_min_score
      end

      def max_score
        Environment.admin_notification_ambiguous_max_score
      end

      def notify_once?(kind, event)
        key = [kind, event.server.id.to_s, event.message.id.to_s]
        return false if @sent_keys[key]

        @sent_keys[key] = true
      end

      def rate_limit_allows?(server_id)
        limit = Environment.admin_notification_rate_limit_per_minute
        return true unless limit.positive?

        now = @clock.call
        timestamps = @rate_limit_timestamps[server_id.to_s]
        timestamps.reject! { |timestamp| timestamp <= now - 60 }
        return false if timestamps.length >= limit

        timestamps << now
        true
      end

      def deliver(message)
        channel = notification_channel
        unless channel
          Logging.warn("admin_notification_channel_unavailable", channel_id: Environment.admin_notification_channel_id)
          return
        end

        channel.send_message(message)
      end

      def notification_channel
        return nil unless @discord_bot

        @discord_bot.channel(Environment.admin_notification_channel_id.to_i)
      end

      def notification_message(title:, event:, strategy:, details:)
        [
          title,
          "server=#{event.server.id}",
          "channel=<##{event.channel.id}>",
          "message=#{event.message.id}",
          "user=<@#{event.user.id}>",
          "strategy=#{strategy}",
          *details
        ].join(" ")
      end

      def score_summary(result)
        result.category_scores.filter_map do |category, score|
          numeric_score = Float(score)
          next unless numeric_score.between?(min_score, max_score)

          "#{category}=#{format("%.2f", numeric_score)}"
        rescue ArgumentError, TypeError
          nil
        end.join(",")
      end
    end
  end
end
