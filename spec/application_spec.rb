require "application"

describe OpenModBot::Application do
  it "initializes with an in-memory backend by default" do
    expect(described_class.new.moderation_store).to be_a(Moderation::Stores::InMemoryStore)
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
      generate_structured: { "structured" => true },
      query: { "ok" => true },
      response_text: "text"
    )
    app = described_class.new(ai_provider: provider)

    expect(app.moderate_text("bad")).to eq(:moderation)
    expect(app.moderation_rewrite("bad", instructions: "Use this voice.")).to eq("Please stop.")
    expect(app.generate_structured(prompt: "classify", schema: {}, schema_name: "result")).to eq("structured" => true)
    expect(app.query("https://example.test", {})).to eq("ok" => true)
    expect(app.response_text("output_text" => "text")).to eq("text")
  end
end
