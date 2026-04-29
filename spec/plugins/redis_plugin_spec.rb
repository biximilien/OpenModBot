require "plugins/redis_plugin"

describe OpenModBot::Plugins::RedisPlugin do
  around do |example|
    original = ENV.to_h
    example.run
  ensure
    ENV.replace(original)
  end

  it "connects using REDIS_URL and exposes a moderation store" do
    redis = Class.new do
      def ping
        "PONG"
      end
    end.new
    plugin = described_class.new
    app = instance_double("Application")
    ENV["REDIS_URL"] = "redis://localhost:6379/0"
    stub_const("Redis", class_double("Redis", new: redis))
    allow(plugin).to receive(:require).with("redis")
    allow(app).to receive(:moderation_store=)

    plugin.boot(app: app)

    expect(app).to have_received(:moderation_store=).with(plugin.moderation_store)
    expect(plugin.redis).to eq(redis)
    expect(plugin.capabilities[:redis_client]).to eq(redis)
    expect(plugin.capabilities[:moderation_store]).to be_a(Moderation::Stores::RedisStore)
    expect(Redis).to have_received(:new).once.with(url: ENV.fetch("REDIS_URL"))
  end

  it "fails clearly when REDIS_URL is missing" do
    ENV.delete("REDIS_URL")

    expect { described_class.new.redis }.to raise_error(
      RuntimeError,
      "REDIS_URL is required when redis plugin is enabled"
    )
  end
end
