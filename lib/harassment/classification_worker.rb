require "json"
require_relative "classification_status"

module Harassment
  class ClassificationWorker
    DEFAULT_MAX_ATTEMPTS = 3
    DEFAULT_RETRY_DELAYS = [60, 300, 1_800].freeze
    NON_RETRYABLE_ERRORS = [ArgumentError, KeyError, JSON::ParserError].freeze

    def initialize(
      interaction_events:,
      classification_jobs:,
      classification_pipeline:,
      classifier:,
      context_assembler: nil,
      on_success: nil,
      max_attempts: DEFAULT_MAX_ATTEMPTS,
      retry_delays: DEFAULT_RETRY_DELAYS
    )
      @interaction_events = interaction_events
      @classification_jobs = classification_jobs
      @classification_pipeline = classification_pipeline
      @classifier = classifier
      @context_assembler = context_assembler
      @on_success = on_success
      @max_attempts = Integer(max_attempts)
      @retry_delays = Array(retry_delays).map { |delay| Integer(delay) }
    end

    def process_due_jobs(as_of: Time.now.utc, limit: nil)
      due_jobs = @classification_jobs.due_jobs(as_of:)
      due_jobs = due_jobs.first(limit) if limit

      due_jobs.filter_map do |job|
        process_job(job, as_of:)
      end
    end

    private

    def process_job(job, as_of:)
      event = @interaction_events.find(job.message_id)
      raise ArgumentError, "interaction event not found for message_id=#{job.message_id}" unless event

      record = @classifier.classify(
        event: event,
        classifier_version: job.classifier_version,
        context: classification_context(event),
        classified_at: as_of,
      )
      record = @classification_pipeline.record_success(record)
      @on_success&.call(event:, record:)
      record
    rescue StandardError => e
      handle_failure(job, e, as_of:)
      nil
    end

    def handle_failure(job, error, as_of:)
      if retryable?(job, error)
        retry_at = as_of + retry_delay(job)
        @classification_pipeline.record_retryable_failure(
          message_id: job.message_id,
          classifier_version: job.classifier_version,
          error: error,
          retry_at: retry_at,
        )
      else
        @classification_pipeline.record_terminal_failure(
          message_id: job.message_id,
          classifier_version: job.classifier_version,
          error: error,
        )
      end
    end

    def classification_context(event)
      return nil unless @context_assembler

      @context_assembler.build_for(event)
    end

    def retryable?(job, error)
      return false if NON_RETRYABLE_ERRORS.any? { |klass| error.is_a?(klass) }

      next_attempt = job.attempt_count + 1
      next_attempt < @max_attempts
    end

    def retry_delay(job)
      @retry_delays.fetch(job.attempt_count, @retry_delays.last)
    end
  end
end
