require "google_ai/provider"

describe GoogleAI::Provider do
  subject(:provider) { described_class.new(transport:, model: "gemini-test") }

  let(:transport) { instance_double("GoogleAI::Transport") }
  let(:moderation_payload) do
    {
      flagged: true,
      categories: {
        harassment: true, hate: false, threat: false, sexual: false, violence: false, self_harm: false
      },
      category_scores: {
        harassment: 0.9, hate: 0.0, threat: 0.0, sexual: 0.0, violence: 0.0, self_harm: 0.0
      }
    }
  end
  let(:response) do
    {
      "candidates" => [
        {
          "content" => {
            "parts" => [
              { "text" => JSON.generate(moderation_payload) }
            ]
          }
        }
      ]
    }
  end

  before do
    allow(transport).to receive(:generate_content).and_return(response)
  end

  it "classifies text into a moderation result" do
    result = provider.moderate_text("bad message")

    expect(result.flagged).to be(true)
    expect(result.categories.fetch("harassment")).to be(true)
    expect(result.category_scores.fetch("harassment")).to eq(0.9)
  end

  it "rewrites text through Gemini content generation" do
    allow(transport).to receive(:generate_content).and_return(
      "candidates" => [{ "content" => { "parts" => [{ "text" => "Please stop." }] } }]
    )

    expect(provider.moderation_rewrite("you are awful", instructions: "Be calm.")).to eq("Please stop.")
  end

  it "maps structured query calls to Gemini structured output" do
    provider.query(
      "https://api.openai.com/v1/responses",
      {
        instructions: "Classify this.",
        input: "message",
        model: "gemini-classifier",
        text: {
          format: {
            schema: {
              type: "object",
              properties: {
                flagged: { type: "boolean" }
              }
            }
          }
        }
      }
    )

    expect(transport).to have_received(:generate_content).with(
      model: "gemini-classifier",
      payload: hash_including(
        contents: [
          {
            parts: [
              { text: "Classify this.\n\nmessage" }
            ]
          }
        ],
        generationConfig: hash_including(
          responseMimeType: "application/json",
          responseJsonSchema: hash_including(
            "type" => "object",
            "properties" => {
              "flagged" => { "type" => "boolean" }
            }
          )
        )
      ),
      user: nil
    )
  end

  it "accepts the shared structured provider keyword contract" do
    provider.generate_structured(
      prompt: "message",
      instructions: "Classify this.",
      model: "gemini-classifier",
      schema_name: "ignored_by_google_ai",
      schema: {
        type: "object",
        properties: {
          flagged: { type: "boolean" }
        }
      }
    )

    expect(transport).to have_received(:generate_content).with(
      model: "gemini-classifier",
      payload: hash_including(
        contents: [
          {
            parts: [
              { text: "Classify this.\n\nmessage" }
            ]
          }
        ]
      ),
      user: nil
    )
  end
end
