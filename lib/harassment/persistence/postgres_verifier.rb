require_relative "../../data_model/keys"
require_relative "postgres_verification/counts"
require_relative "postgres_verification/known_message_checks"
require_relative "postgres_verification/spot_checks"
require_relative "../repositories/postgres_classification_job_repository"
require_relative "../repositories/postgres_classification_record_repository"
require_relative "../repositories/postgres_interaction_event_repository"

module Harassment
  class PostgresVerifier
    TABLES = {
      interaction_events: {
        redis_key: DataModel::Keys.harassment_interaction_events,
        table_name: "interaction_events",
      },
      classification_records: {
        redis_key: DataModel::Keys.harassment_classification_records,
        table_name: "classification_records",
      },
      classification_jobs: {
        redis_key: DataModel::Keys.harassment_classification_jobs,
        table_name: "classification_jobs",
      },
    }.freeze

    DEFAULT_SPOT_CHECK_LIMIT = 5

    def initialize(
      redis:,
      connection:,
      interaction_event_repository: nil,
      classification_record_repository: nil,
      classification_job_repository: nil
    )
      @redis = redis
      @connection = connection
      @interaction_event_repository =
        interaction_event_repository || Repositories::PostgresInteractionEventRepository.new(connection:)
      @classification_record_repository =
        classification_record_repository || Repositories::PostgresClassificationRecordRepository.new(connection:)
      @classification_job_repository =
        classification_job_repository || Repositories::PostgresClassificationJobRepository.new(connection:)
    end

    def run(spot_check_limit: DEFAULT_SPOT_CHECK_LIMIT, verify_message_ids: [])
      counts = PostgresVerification::Counts.new(redis: @redis, connection: @connection, tables: TABLES)
      summary = counts.run
      summary[:spot_checks] = spot_checks.run(limit: spot_check_limit)
      summary[:known_message_ids] = known_message_checks.run(verify_message_ids)
      summary[:relationship_edges] = counts.postgres_counts_for("relationship_edges")
      summary
    end

    private

    def spot_checks
      PostgresVerification::SpotChecks.new(
        redis: @redis,
        interaction_event_repository: @interaction_event_repository,
        classification_record_repository: @classification_record_repository,
        classification_job_repository: @classification_job_repository,
      )
    end

    def known_message_checks
      PostgresVerification::KnownMessageChecks.new(
        redis: @redis,
        interaction_event_repository: @interaction_event_repository,
        classification_record_repository: @classification_record_repository,
        classification_job_repository: @classification_job_repository,
      )
    end
  end
end
