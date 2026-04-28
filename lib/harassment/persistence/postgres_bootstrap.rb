require "json"
require_relative "../../data_model/keys"
require_relative "../classification/job"
require_relative "../classification/record"
require_relative "../interaction/event"

module Harassment
  class PostgresBootstrap
    def initialize(redis:, interaction_events:, classification_records:, classification_jobs:)
      @redis = redis
      @interaction_events = interaction_events
      @classification_records = classification_records
      @classification_jobs = classification_jobs
    end

    def run
      {
        interaction_events: import_interaction_events,
        classification_records: import_classification_records,
        classification_jobs: import_classification_jobs,
      }
    end

    private

    def import_interaction_events
      import_hash(DataModel::Keys.harassment_interaction_events) do |payload|
        @interaction_events.save(build_interaction_event(payload))
      end
    end

    def import_classification_records
      import_hash(DataModel::Keys.harassment_classification_records) do |payload|
        @classification_records.save(build_classification_record(payload))
      end
    end

    def import_classification_jobs
      import_hash(DataModel::Keys.harassment_classification_jobs) do |payload|
        job = build_classification_job(payload)
        existing = @classification_jobs.find(
          server_id: job.server_id,
          message_id: job.message_id,
          classifier_version: job.classifier_version,
        )
        raise ArgumentError, "classification job already exists" if existing

        @classification_jobs.enqueue_unique(job)
      end
    end

    def import_hash(key)
      summary = { imported: 0, skipped: 0 }
      @redis.hgetall(key).each_value do |payload|
        
          yield payload
          summary[:imported] += 1
        rescue ArgumentError => e
          raise unless e.message =~ /already exists/

          summary[:skipped] += 1
        
      end
      summary
    end

    def build_interaction_event(payload)
      data = JSON.parse(payload, symbolize_names: true)
      InteractionEvent.build(**data)
    end

    def build_classification_record(payload)
      data = JSON.parse(payload, symbolize_names: true)
      ClassificationRecord.build(**data)
    end

    def build_classification_job(payload)
      data = JSON.parse(payload, symbolize_names: true)
      ClassificationJob.build(**data)
    end
  end
end
