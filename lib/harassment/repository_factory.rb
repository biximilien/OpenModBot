require_relative "repositories/in_memory_classification_cache_repository"
require_relative "repositories/in_memory_classification_job_repository"
require_relative "repositories/in_memory_classification_record_repository"
require_relative "repositories/in_memory_interaction_event_repository"
require_relative "repositories/in_memory_server_rate_limit_repository"
require_relative "repositories/postgres_interaction_event_repository"
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
      else
        raise NotImplementedError, "Postgres harassment classification-cache repositories are not implemented yet"
      end
    end

    def server_rate_limits
      case @backend
      when "memory"
        Repositories::InMemoryServerRateLimitRepository.new
      when "redis"
        Repositories::RedisServerRateLimitRepository.new(redis: redis!)
      else
        raise NotImplementedError, "Postgres harassment rate-limit repositories are not implemented yet"
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
