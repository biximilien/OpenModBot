require_relative "../environment"
require_relative "../lib/application"
require_relative "../lib/plugin_registry"
require_relative "../lib/harassment/persistence/postgres_verifier"

app = ModerationGPT::Application.new
plugins = ModerationGPT::PluginRegistry.from_environment
postgres_plugin = plugins.find_plugin(ModerationGPT::Plugins::PostgresPlugin)
raise "verify_harassment_postgres requires the postgres plugin to be enabled" unless postgres_plugin

message_ids = ARGV

verifier = Harassment::PostgresVerifier.new(
  redis: app.redis,
  connection: postgres_plugin.database_connection,
)

summary = verifier.run(verify_message_ids: message_ids)

puts "Harassment Postgres verification"
summary.each do |name, counts|
  next if name == :spot_checks || name == :relationship_edges

  puts "- #{name}: redis_total=#{counts[:redis_total]} postgres_total=#{counts[:postgres_total]} matches=#{counts[:matches]}"
  counts[:redis_by_server].each do |server_id, redis_count|
    postgres_count = counts[:postgres_by_server].fetch(server_id, 0)
    puts "  - server #{server_id}: redis=#{redis_count} postgres=#{postgres_count}"
  end
end

relationship_edges = summary.fetch(:relationship_edges)
puts "- relationship_edges: postgres_total=#{relationship_edges[:total]}"
relationship_edges[:by_server].each do |server_id, count|
  puts "  - server #{server_id}: postgres=#{count}"
end

puts "Spot checks"
summary.fetch(:spot_checks).each do |name, details|
  puts "- #{name}: sampled=#{details[:sampled]} matched=#{details[:matched]} matches=#{details[:matches]}"
  details[:mismatches].each do |mismatch|
    puts "  - mismatch: #{mismatch}"
  end
end

unless message_ids.empty?
  puts "Known message IDs"
  summary.fetch(:known_message_ids).each do |message_id, details|
    puts "- message #{message_id}"
    details.each do |name, verification|
      if verification.key?(:entries)
        puts "  - #{name}: found_in_redis=#{verification[:found_in_redis]} found_in_postgres=#{verification[:found_in_postgres]} matches=#{verification[:matches]}"
        verification[:entries].each do |entry|
          puts "    - entry: #{entry}"
        end
      else
        puts "  - #{name}: #{verification}"
      end
    end
  end
end
