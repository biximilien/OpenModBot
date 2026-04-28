require "open_ai"

describe OpenAI do
  include described_class

  describe "#anonymized_user_hash" do
    it "hashes user ids for telemetry" do
      user = instance_double("User", id: 123)

      expect(anonymized_user_hash(user)).to eq(Telemetry::Anonymizer.hash(123))
    end

    it "returns nil without a user" do
      expect(anonymized_user_hash(nil)).to be_nil
    end
  end

  describe "#moderate_text" do
    it "returns a moderation result" do
      allow(self).to receive(:query).and_return(
        "results" => [
          {
            "flagged" => true,
            "categories" => { "harassment" => true },
            "category_scores" => { "harassment" => 0.98 },
          },
        ],
      )

      result = moderate_text("you are awful")

      expect(result.flagged).to be(true)
      expect(result.categories).to eq("harassment" => true)
      expect(result.category_scores).to eq("harassment" => 0.98)
    end
  end

  describe "#moderation_rewrite" do
    it "returns output_text from the Responses API response" do
      allow(self).to receive(:query).and_return("output_text" => "Let's talk this through.")

      expect(moderation_rewrite("you are awful")).to eq("Let's talk this through.")
    end

    it "passes rewrite instructions to the Responses API" do
      allow(self).to receive(:query).and_return("output_text" => "Please stop.")

      moderation_rewrite("you are awful", nil, instructions: "Use this voice.")

      expect(self).to have_received(:query).with(
        "https://api.openai.com/v1/responses",
        hash_including(instructions: "Use this voice."),
        nil,
      )
    end

    it "falls back to parsing output content blocks" do
      response = {
        "output" => [
          {
            "content" => [
              { "type" => "output_text", "text" => "Please reconsider this." },
            ],
          },
        ],
      }

      expect(response_text(response)).to eq("Please reconsider this.")
    end
  end

  describe "#generate_structured" do
    it "maps structured generation to the Responses API schema format" do
      allow(self).to receive(:query).and_return("output_text" => '{"ok":true}')

      generate_structured(
        prompt: "Classify this",
        schema: { type: "object" },
        model: "gpt-test",
        instructions: "Return JSON.",
        schema_name: "test_schema",
      )

      expect(self).to have_received(:query).with(
        "https://api.openai.com/v1/responses",
        hash_including(
          model: "gpt-test",
          instructions: "Return JSON.",
          input: "Classify this",
          text: {
            format: {
              type: "json_schema",
              name: "test_schema",
              strict: true,
              schema: { type: "object" },
            },
          },
        ),
        nil,
      )
    end
  end

  describe OpenAI::Provider do
    it "implements the generic AI provider contract" do
      expect(described_class.new).to be_a(ModerationGPT::AI::Provider)
    end
  end
end
