require_relative "../environment"
require_relative "../lib/application"
require_relative "../lib/plugin_registry"
require_relative "../lib/harassment/persistence/postgres_bootstrap"
require_relative "../lib/harassment/repositories/postgres_interaction_event_repository"
require_relative "../lib/harassment/repositories/postgres_classification_record_repository"
require_relative "../lib/harassment/repositories/postgres_classification_job_repository"

app = ModerationGPT::Application.new
plugins = ModerationGPT::PluginRegistry.from_environment
postgres_plugin = plugins.find_plugin(ModerationGPT::Plugins::PostgresPlugin)
raise "bootstrap_harassment_postgres requires the postgres plugin to be enabled" unless postgres_plugin

connection = postgres_plugin.database_connection

bootstrap = Harassment::PostgresBootstrap.new(
  redis: app.redis,
  interaction_events: Harassment::Repositories::PostgresInteractionEventRepository.new(connection: connection),
  classification_records: Harassment::Repositories::PostgresClassificationRecordRepository.new(connection: connection),
  classification_jobs: Harassment::Repositories::PostgresClassificationJobRepository.new(connection: connection),
)

summary = bootstrap.run

puts "Harassment Postgres bootstrap complete"
summary.each do |name, counts|
  puts "- #{name}: imported=#{counts[:imported]} skipped=#{counts[:skipped]}"
end
