require "time"
require_relative "classification_status"

module Harassment
  InteractionEvent = Data.define(
    :message_id,
    :server_id,
    :channel_id,
    :author_id,
    :target_user_ids,
    :timestamp,
    :raw_content,
    :classification_status,
    :content_retention_expires_at,
    :content_redacted_at,
  ) do
    def self.build(
      message_id:,
      server_id:,
      channel_id:,
      author_id:,
      target_user_ids: [],
      timestamp: Time.now.utc,
      raw_content:,
      classification_status: ClassificationStatus::PENDING,
      content_retention_expires_at: nil,
      content_redacted_at: nil
    )
      new(
        message_id: identifier!(message_id, "message_id"),
        server_id: identifier!(server_id, "server_id"),
        channel_id: identifier!(channel_id, "channel_id"),
        author_id: identifier!(author_id, "author_id"),
        target_user_ids: normalized_target_user_ids(target_user_ids),
        timestamp: time!(timestamp, "timestamp"),
        raw_content: string!(raw_content, "raw_content"),
        classification_status: classification_status!(classification_status),
        content_retention_expires_at: optional_time(content_retention_expires_at, "content_retention_expires_at"),
        content_redacted_at: optional_time(content_redacted_at, "content_redacted_at"),
      )
    end

    def with_classification_status(status)
      self.class.build(**to_h, classification_status: status)
    end

    def retention_expired?(as_of: Time.now.utc)
      return false unless content_retention_expires_at

      content_retention_expires_at <= as_of.utc
    end

    def redacted?
      !content_redacted_at.nil?
    end

    def redact_content(redacted_at: Time.now.utc, replacement: "[REDACTED]")
      self.class.build(
        **to_h,
        raw_content: replacement.to_s,
        content_redacted_at: redacted_at,
      )
    end

    class << self
      private

      def normalized_target_user_ids(target_user_ids)
        Array(target_user_ids).map { |user_id| identifier!(user_id, "target_user_id") }.uniq
      end

      def classification_status!(value)
        ClassificationStatus.normalize!(string!(value, "classification_status"), field_name: "classification_status")
      end

      def identifier!(value, name)
        normalized = value.to_s.strip
        raise ArgumentError, "#{name} must not be empty" if normalized.empty?

        normalized
      end

      def string!(value, name)
        normalized = value.to_s
        raise ArgumentError, "#{name} must not be empty" if normalized.empty?

        normalized
      end

      def time!(value, name)
        case value
        when Time then value.utc
        else
          Time.parse(value.to_s).utc
        end
      rescue ArgumentError
        raise ArgumentError, "#{name} must be a valid time"
      end

      def optional_time(value, name)
        return nil if value.nil?

        time!(value, name)
      end
    end
  end
end
