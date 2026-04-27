require_relative "../environment"
require_relative "../lib/plugin_registry"
require_relative "../lib/harassment/relationship/edge_rebuilder"
require_relative "../lib/harassment/persistence/repository_factory"
require_relative "../lib/harassment/risk/score_definition"

plugins = ModerationGPT::PluginRegistry.from_environment
postgres_plugin = plugins.find_plugin(ModerationGPT::Plugins::PostgresPlugin)
raise "rebuild_harassment_relationship_edges requires PLUGINS=postgres and DATABASE_URL to be configured" unless postgres_plugin

factory = Harassment::RepositoryFactory.new(
  backend: "postgres",
  connection: postgres_plugin.database_connection,
)
server_id = ARGV[0]

rebuilder = Harassment::RelationshipEdgeRebuilder.new(
  interaction_events: factory.interaction_events,
  classification_records: factory.classification_records,
  relationship_edges: factory.relationship_edges,
  score_version: Harassment::ScoreDefinition::VERSION,
  server_id: server_id,
)

summary = rebuilder.run

puts "Harassment relationship-edge rebuild complete"
puts "- score_version=#{Harassment::ScoreDefinition::VERSION}"
puts "- server_scope=#{server_id || 'all'}"
summary.each do |name, count|
  puts "- #{name}=#{count}"
end
