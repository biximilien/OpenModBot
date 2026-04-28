require "time"
require_relative "record"
require_relative "status"
require_relative "job"

module Harassment
  class ClassificationPipeline
    def initialize(interaction_events:, classification_records:, classification_jobs:)
      @interaction_events = interaction_events
      @classification_records = classification_records
      @classification_jobs = classification_jobs
    end

    def enqueue(message_id:, server_id:, classifier_version:, enqueued_at: Time.now.utc)
      event = @interaction_events.find(message_id, server_id:)
      unless event
        raise ArgumentError, "interaction event not found for server_id=#{server_id} message_id=#{message_id}"
      end

      existing_job = @classification_jobs.find(server_id: event.server_id, message_id:, classifier_version:)
      return existing_job if existing_job

      @interaction_events.update_classification_status(message_id, ClassificationStatus::PENDING, server_id: event.server_id)

      job = ClassificationJob.build(
        server_id: event.server_id,
        message_id: message_id,
        classifier_version: classifier_version,
        status: ClassificationStatus::PENDING,
        enqueued_at: enqueued_at,
        updated_at: enqueued_at,
        available_at: enqueued_at,
      )

      @classification_jobs.enqueue_unique(job)
    end

    def record_success(record)
      existing_record = @classification_records.find(
        server_id: record.server_id,
        message_id: record.message_id,
        classifier_version: record.classifier_version,
      )
      return existing_record if existing_record

      @classification_records.save(record)
      @interaction_events.update_classification_status(record.message_id, ClassificationStatus::CLASSIFIED, server_id: record.server_id)
      update_job_status(record.server_id, record.message_id, record.classifier_version, ClassificationStatus::CLASSIFIED, updated_at: record.classified_at)

      record
    end

    def record_retryable_failure(server_id:, message_id:, classifier_version:, error:, retry_at:)
      @interaction_events.update_classification_status(message_id, ClassificationStatus::FAILED_RETRYABLE, server_id:)
      update_failed_job(
        server_id:,
        message_id:,
        classifier_version:,
        status: ClassificationStatus::FAILED_RETRYABLE,
        error:,
        available_at: retry_at,
      )
    end

    def record_terminal_failure(server_id:, message_id:, classifier_version:, error:)
      @interaction_events.update_classification_status(message_id, ClassificationStatus::FAILED_TERMINAL, server_id:)
      update_failed_job(
        server_id:,
        message_id:,
        classifier_version:,
        status: ClassificationStatus::FAILED_TERMINAL,
        error:,
        available_at: Time.now.utc,
      )
    end

    def defer_job(server_id:, message_id:, classifier_version:, available_at:)
      deferred_job = fetch_job(server_id:, message_id:, classifier_version:).with_status(
        ClassificationStatus::PENDING,
        available_at: available_at,
        updated_at: available_at,
      )
      @classification_jobs.save(deferred_job)
      @interaction_events.update_classification_status(message_id, ClassificationStatus::PENDING, server_id:)
      deferred_job
    end

    private

    def update_failed_job(server_id:, message_id:, classifier_version:, status:, error:, available_at:)
      job = fetch_job(server_id:, message_id:, classifier_version:)
      updated_job = job
                    .increment_attempts(updated_at: available_at)
                    .with_status(
                      status,
                      available_at: available_at,
                      last_error_class: error.class.name,
                      last_error_message: error.message,
                      updated_at: available_at,
                    )
      @classification_jobs.save(updated_job)
    end

    def update_job_status(server_id, message_id, classifier_version, status, updated_at:)
      job = fetch_job(server_id:, message_id:, classifier_version:)
      @classification_jobs.save(job.with_status(status, updated_at:, available_at: updated_at))
    end

    def fetch_job(server_id:, message_id:, classifier_version:)
      @classification_jobs.find(server_id:, message_id:, classifier_version:) ||
        raise(ArgumentError, "classification job not found for server_id=#{server_id} message_id=#{message_id} classifier_version=#{ClassifierVersion.build(classifier_version)}")
    end
  end
end
