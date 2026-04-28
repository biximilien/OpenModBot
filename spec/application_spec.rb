require "application"

class FakeApplicationRedis
  def ping
    "PONG"
  end
end

describe ModerationGPT::Application do
  before do
    allow(Redis).to receive(:new).and_return(FakeApplicationRedis.new)
  end

  it "initializes the backend" do
    described_class.new

    expect(Redis).to have_received(:new).with(url: Environment.redis_url)
  end

  it "exposes backend methods" do
    expect(described_class.new).to respond_to(:get_watch_list_users)
  end

  it "exposes AI provider methods" do
    expect(described_class.new).to respond_to(:moderate_text)
  end

  it "delegates AI calls to the configured provider" do
    provider = instance_double(
      "AIProvider",
      moderate_text: :moderation,
      moderation_rewrite: "Please stop.",
      query: { "ok" => true },
      response_text: "text",
    )
    app = described_class.new(ai_provider: provider)

    expect(app.moderate_text("bad")).to eq(:moderation)
    expect(app.moderation_rewrite("bad", instructions: "Use this voice.")).to eq("Please stop.")
    expect(app.query("https://example.test", {})).to eq("ok" => true)
    expect(app.response_text("output_text" => "text")).to eq("text")
  end
end
