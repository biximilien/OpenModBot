require "time"
require_relative "classification_status"
require_relative "classifier_version"

module Harassment
  ClassificationJob = Data.define(
    :server_id,
    :message_id,
    :classifier_version,
    :status,
    :attempt_count,
    :available_at,
    :last_error_class,
    :last_error_message,
    :enqueued_at,
    :updated_at,
  ) do
    def self.build(
      server_id:,
      message_id:,
      classifier_version:,
      status: ClassificationStatus::PENDING,
      attempt_count: 0,
      available_at: Time.now.utc,
      last_error_class: nil,
      last_error_message: nil,
      enqueued_at: Time.now.utc,
      updated_at: enqueued_at
    )
      new(
        server_id: identifier!(server_id, "server_id"),
        message_id: identifier!(message_id, "message_id"),
        classifier_version: classifier_version!(classifier_version),
        status: status!(status),
        attempt_count: non_negative_integer!(attempt_count, "attempt_count"),
        available_at: time!(available_at, "available_at"),
        last_error_class: optional_string(last_error_class),
        last_error_message: optional_string(last_error_message),
        enqueued_at: time!(enqueued_at, "enqueued_at"),
        updated_at: time!(updated_at, "updated_at"),
      )
    end

    def with_status(status, available_at: self.available_at, last_error_class: nil, last_error_message: nil, updated_at: Time.now.utc)
      self.class.build(
        **to_h,
        status: status,
        available_at: available_at,
        last_error_class: last_error_class,
        last_error_message: last_error_message,
        updated_at: updated_at,
      )
    end

    def increment_attempts(updated_at: Time.now.utc)
      self.class.build(
        **to_h,
        attempt_count: attempt_count + 1,
        updated_at: updated_at,
      )
    end

    class << self
      private

      def identifier!(value, name)
        normalized = value.to_s.strip
        raise ArgumentError, "#{name} must not be empty" if normalized.empty?

        normalized
      end

      def classifier_version!(value)
        value.is_a?(ClassifierVersion) ? value : ClassifierVersion.build(value)
      end

      def status!(value)
        ClassificationStatus.normalize!(value)
      end

      def non_negative_integer!(value, name)
        integer = Integer(value)
        raise ArgumentError, "#{name} must be non-negative" if integer.negative?

        integer
      rescue ArgumentError, TypeError
        raise ArgumentError, "#{name} must be non-negative"
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

      def optional_string(value)
        return nil if value.nil?

        normalized = value.to_s
        normalized.empty? ? nil : normalized
      end
    end
  end
end
