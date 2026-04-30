require_relative "../repositories/in_memory_classification_cache_repository"
require_relative "../repositories/in_memory_classification_job_repository"
require_relative "../repositories/in_memory_classification_record_repository"
require_relative "../repositories/in_memory_interaction_event_repository"
require_relative "../repositories/in_memory_relationship_edge_repository"
require_relative "../repositories/in_memory_server_rate_limit_repository"
require_relative "../repositories/postgres_classification_job_repository"
require_relative "../repositories/postgres_classification_record_repository"
require_relative "../repositories/postgres_classification_cache_repository"
require_relative "../repositories/postgres_interaction_event_repository"
require_relative "../repositories/postgres_relationship_edge_repository"
require_relative "../repositories/postgres_server_rate_limit_repository"
require_relative "legacy_redis_repositories"

module Harassment
  class RepositoryFactory
    REPOSITORIES = {
      interaction_events: {
        "memory" => Repositories::InMemoryInteractionEventRepository,
        "redis" => LegacyRedisRepositories.repository_for(:interaction_events),
        "postgres" => Repositories::PostgresInteractionEventRepository
      },
      classification_records: {
        "memory" => Repositories::InMemoryClassificationRecordRepository,
        "redis" => LegacyRedisRepositories.repository_for(:classification_records),
        "postgres" => Repositories::PostgresClassificationRecordRepository
      },
      classification_jobs: {
        "memory" => Repositories::InMemoryClassificationJobRepository,
        "redis" => LegacyRedisRepositories.repository_for(:classification_jobs),
        "postgres" => Repositories::PostgresClassificationJobRepository
      },
      classification_cache: {
        "memory" => Repositories::InMemoryClassificationCacheRepository,
        "redis" => LegacyRedisRepositories.repository_for(:classification_cache),
        "postgres" => Repositories::PostgresClassificationCacheRepository
      },
      server_rate_limits: {
        "memory" => Repositories::InMemoryServerRateLimitRepository,
        "redis" => LegacyRedisRepositories.repository_for(:server_rate_limits),
        "postgres" => Repositories::PostgresServerRateLimitRepository
      },
      relationship_edges: {
        "memory" => Repositories::InMemoryRelationshipEdgeRepository,
        "redis" => LegacyRedisRepositories.repository_for(:relationship_edges),
        "postgres" => Repositories::PostgresRelationshipEdgeRepository
      }
    }.freeze

    def initialize(backend:, redis: nil, connection: nil)
      @redis = redis
      @connection = connection
      @backend = normalize_backend(backend)
    end

    def interaction_events
      build_repository(:interaction_events)
    end

    def classification_records
      build_repository(:classification_records)
    end

    def classification_jobs
      build_repository(:classification_jobs)
    end

    def classification_cache
      build_repository(:classification_cache)
    end

    def server_rate_limits
      build_repository(:server_rate_limits)
    end

    def relationship_edges
      build_repository(:relationship_edges)
    end

    private

    def build_repository(kind)
      repository_class = REPOSITORIES.fetch(kind).fetch(@backend) do
        raise NotImplementedError, "unsupported harassment #{kind.to_s.tr("_", "-")} backend: #{@backend}"
      end
      if @backend == "postgres"
        repository_class.new(connection: connection!)
      elsif @backend == "redis" && redis_repository?(kind)
        repository_class.new(redis: redis!)
      else
        repository_class.new
      end
    end

    def redis_repository?(kind)
      LegacyRedisRepositories.redis_backed?(kind)
    end

    def normalize_backend(backend)
      normalized = backend.to_s.strip.downcase
      return "memory" if normalized.empty? && @redis.nil?
      return "redis" if normalized.empty?
      return normalized if %w[memory redis postgres].include?(normalized)

      raise ArgumentError, "unsupported harassment storage backend: #{backend}"
    end

    def redis!
      return @redis if @redis

      raise ArgumentError, "redis backend requires a Redis client"
    end

    def connection!
      return @connection if @connection

      raise ArgumentError, "postgres backend requires a database connection"
    end
  end
end
