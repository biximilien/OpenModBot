module Harassment
  module ClassificationStatus
    PENDING = "pending".freeze
    CLASSIFIED = "classified".freeze
    FAILED_RETRYABLE = "failed_retryable".freeze
    FAILED_TERMINAL = "failed_terminal".freeze

    ALL = [
      PENDING,
      CLASSIFIED,
      FAILED_RETRYABLE,
      FAILED_TERMINAL,
    ].freeze

    def self.normalize!(value, field_name: "status")
      normalized = value.to_s
      return normalized if ALL.include?(normalized)

      raise ArgumentError, "#{field_name} must be one of: #{ALL.join(', ')}"
    end
  end
end
