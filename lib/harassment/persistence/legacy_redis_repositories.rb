require_relative "../repositories/in_memory_relationship_edge_repository"
require_relative "../repositories/redis_classification_cache_repository"
require_relative "../repositories/redis_classification_job_repository"
require_relative "../repositories/redis_classification_record_repository"
require_relative "../repositories/redis_interaction_event_repository"
require_relative "../repositories/redis_server_rate_limit_repository"

module Harassment
  module LegacyRedisRepositories
    REPOSITORIES = {
      interaction_events: Repositories::RedisInteractionEventRepository,
      classification_records: Repositories::RedisClassificationRecordRepository,
      classification_jobs: Repositories::RedisClassificationJobRepository,
      classification_cache: Repositories::RedisClassificationCacheRepository,
      server_rate_limits: Repositories::RedisServerRateLimitRepository,
      relationship_edges: Repositories::InMemoryRelationshipEdgeRepository
    }.freeze

    def self.repository_for(kind)
      REPOSITORIES.fetch(kind)
    end

    def self.redis_backed?(kind)
      repository_for(kind) != Repositories::InMemoryRelationshipEdgeRepository
    end
  end
end
