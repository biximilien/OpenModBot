require_relative "repositories/in_memory_classification_cache_repository"
require_relative "repositories/in_memory_classification_job_repository"
require_relative "repositories/in_memory_classification_record_repository"
require_relative "repositories/in_memory_interaction_event_repository"
require_relative "repositories/in_memory_relationship_edge_repository"
require_relative "repositories/in_memory_server_rate_limit_repository"
require_relative "repositories/postgres_classification_job_repository"
require_relative "repositories/postgres_classification_record_repository"
require_relative "repositories/postgres_classification_cache_repository"
require_relative "repositories/postgres_interaction_event_repository"
require_relative "repositories/postgres_relationship_edge_repository"
require_relative "repositories/postgres_server_rate_limit_repository"
require_relative "repositories/redis_classification_cache_repository"
require_relative "repositories/redis_classification_job_repository"
require_relative "repositories/redis_classification_record_repository"
require_relative "repositories/redis_interaction_event_repository"
require_relative "repositories/redis_server_rate_limit_repository"

module Harassment
  class RepositoryFactory
    def initialize(backend:, redis: nil, connection: nil)
      @redis = redis
      @connection = connection
      @backend = normalize_backend(backend)
    end

    def interaction_events
      case @backend
      when "memory"
        Repositories::InMemoryInteractionEventRepository.new
      when "redis"
        Repositories::RedisInteractionEventRepository.new(redis: redis!)
      when "postgres"
        Repositories::PostgresInteractionEventRepository.new(connection: connection!)
      else
        raise NotImplementedError, "Postgres harassment interaction repositories are not implemented yet"
      end
    end

    def classification_records
      case @backend
      when "memory"
        Repositories::InMemoryClassificationRecordRepository.new
      when "redis"
        Repositories::RedisClassificationRecordRepository.new(redis: redis!)
      when "postgres"
        Repositories::PostgresClassificationRecordRepository.new(connection: connection!)
      else
        raise NotImplementedError, "Postgres harassment classification-record repositories are not implemented yet"
      end
    end

    def classification_jobs
      case @backend
      when "memory"
        Repositories::InMemoryClassificationJobRepository.new
      when "redis"
        Repositories::RedisClassificationJobRepository.new(redis: redis!)
      when "postgres"
        Repositories::PostgresClassificationJobRepository.new(connection: connection!)
      else
        raise NotImplementedError, "Postgres harassment classification-job repositories are not implemented yet"
      end
    end

    def classification_cache
      case @backend
      when "memory"
        Repositories::InMemoryClassificationCacheRepository.new
      when "redis"
        Repositories::RedisClassificationCacheRepository.new(redis: redis!)
      when "postgres"
        Repositories::PostgresClassificationCacheRepository.new(connection: connection!)
      else
        raise NotImplementedError, "unsupported harassment classification-cache backend: #{@backend}"
      end
    end

    def server_rate_limits
      case @backend
      when "memory"
        Repositories::InMemoryServerRateLimitRepository.new
      when "redis"
        Repositories::RedisServerRateLimitRepository.new(redis: redis!)
      when "postgres"
        Repositories::PostgresServerRateLimitRepository.new(connection: connection!)
      else
        raise NotImplementedError, "unsupported harassment rate-limit backend: #{@backend}"
      end
    end

    def relationship_edges
      case @backend
      when "memory", "redis"
        Repositories::InMemoryRelationshipEdgeRepository.new
      when "postgres"
        Repositories::PostgresRelationshipEdgeRepository.new(connection: connection!)
      else
        raise NotImplementedError, "unsupported harassment relationship-edge backend: #{@backend}"
      end
    end

    private

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
