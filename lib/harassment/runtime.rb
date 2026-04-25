require_relative "cached_classifier"
require_relative "classification_pipeline"
require_relative "classification_worker"
require_relative "context_assembler"
require_relative "message_ingestor"
require_relative "server_rate_limiter"
require_relative "repositories/in_memory_classification_cache_repository"
require_relative "repositories/in_memory_classification_job_repository"
require_relative "repositories/in_memory_classification_record_repository"
require_relative "repositories/in_memory_interaction_event_repository"
require_relative "repositories/in_memory_server_rate_limit_repository"
require_relative "repositories/redis_classification_cache_repository"
require_relative "repositories/redis_classification_job_repository"
require_relative "repositories/redis_classification_record_repository"
require_relative "repositories/redis_interaction_event_repository"
require_relative "repositories/redis_server_rate_limit_repository"
require_relative "../../environment"

module Harassment
  class Runtime
    attr_reader :classification_jobs, :classification_pipeline, :classification_records, :interaction_events

    def initialize(
      redis: nil,
      interaction_events: nil,
      classification_records: nil,
      classification_jobs: nil,
      classification_cache: nil,
      server_rate_limits: nil,
      classifier_version:,
      classifier:,
      classifier_cache_ttl_seconds: Environment.harassment_classifier_cache_ttl_seconds,
      classifier_rate_limit_per_minute: Environment.harassment_classifier_rate_limit_per_minute,
      on_classification: nil
    )
      @interaction_events = interaction_events || self.class.send(:default_interaction_events, redis)
      @classification_records = classification_records || self.class.send(:default_classification_records, redis)
      @classification_jobs = classification_jobs || self.class.send(:default_classification_jobs, redis)
      @classification_cache = classification_cache || self.class.send(:default_classification_cache, redis)
      @server_rate_limits = server_rate_limits || self.class.send(:default_server_rate_limits, redis)
      @classifier_version = classifier_version.is_a?(ClassifierVersion) ? classifier_version : ClassifierVersion.build(classifier_version)
      @classifier = wrap_classifier(classifier, ttl_seconds: classifier_cache_ttl_seconds)
      @rate_limiter = build_rate_limiter(limit_per_minute: classifier_rate_limit_per_minute)
      @classification_pipeline = ClassificationPipeline.new(
        interaction_events: @interaction_events,
        classification_records: @classification_records,
        classification_jobs: @classification_jobs,
      )
      @message_ingestor = MessageIngestor.new(
        interaction_events: @interaction_events,
        classification_pipeline: @classification_pipeline,
        classifier_version: @classifier_version,
      )
      @context_assembler = ContextAssembler.new(interaction_events: @interaction_events)
      @classification_worker = ClassificationWorker.new(
        interaction_events: @interaction_events,
        classification_jobs: @classification_jobs,
        classification_pipeline: @classification_pipeline,
        classifier: @classifier,
        rate_limiter: @rate_limiter,
        context_assembler: @context_assembler,
        on_success: on_classification,
      )
    end

    def ingest_message(event)
      @message_ingestor.ingest(event)
    end

    def process_due_classifications(as_of: Time.now.utc, limit: nil)
      @classification_worker.process_due_jobs(as_of:, limit:)
    end

    class << self
      private

      def default_interaction_events(redis)
        redis ? Repositories::RedisInteractionEventRepository.new(redis:) : Repositories::InMemoryInteractionEventRepository.new
      end

      def default_classification_records(redis)
        redis ? Repositories::RedisClassificationRecordRepository.new(redis:) : Repositories::InMemoryClassificationRecordRepository.new
      end

      def default_classification_jobs(redis)
        redis ? Repositories::RedisClassificationJobRepository.new(redis:) : Repositories::InMemoryClassificationJobRepository.new
      end

      def default_classification_cache(redis)
        redis ? Repositories::RedisClassificationCacheRepository.new(redis:) : Repositories::InMemoryClassificationCacheRepository.new
      end

      def default_server_rate_limits(redis)
        redis ? Repositories::RedisServerRateLimitRepository.new(redis:) : Repositories::InMemoryServerRateLimitRepository.new
      end
    end

    private

    def wrap_classifier(classifier, ttl_seconds:)
      return classifier unless Integer(ttl_seconds).positive?

      CachedClassifier.new(
        delegate: classifier,
        cache_repository: @classification_cache,
        ttl_seconds: ttl_seconds,
      )
    end

    def build_rate_limiter(limit_per_minute:)
      return nil unless Integer(limit_per_minute).positive?

      ServerRateLimiter.new(
        repository: @server_rate_limits,
        limit_per_minute: limit_per_minute,
      )
    end
  end
end
