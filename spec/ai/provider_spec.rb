require "ai/provider"

describe ModerationGPT::AI::Provider do
  subject(:provider) { described_class.new }

  it "requires concrete providers to implement moderation" do
    expect { provider.moderate_text("text") }.to raise_error(NotImplementedError, /must implement #moderate_text/)
  end

  it "requires concrete providers to implement rewrites" do
    expect { provider.moderation_rewrite("text", instructions: "Be clear.") }.to raise_error(NotImplementedError, /must implement #moderation_rewrite/)
  end

  it "requires concrete providers to implement structured generation" do
    expect do
      provider.generate_structured(prompt: "text", schema: {})
    end.to raise_error(NotImplementedError, /must implement #generate_structured/)
  end

  it "requires concrete providers to implement raw queries" do
    expect { provider.query("https://example.test", {}) }.to raise_error(NotImplementedError, /must implement #query/)
  end

  it "requires concrete providers to implement response text extraction" do
    expect { provider.response_text({}) }.to raise_error(NotImplementedError, /must implement #response_text/)
  end
end
