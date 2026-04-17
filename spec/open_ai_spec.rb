require "open_ai"

describe OpenAI do
  include OpenAI

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

      expect(result.flagged).to eq(true)
      expect(result.categories).to eq("harassment" => true)
      expect(result.category_scores).to eq("harassment" => 0.98)
    end
  end

  describe "#moderation_rewrite" do
    it "returns output_text from the Responses API response" do
      allow(self).to receive(:query).and_return("output_text" => "Let's talk this through.")

      expect(moderation_rewrite("you are awful")).to eq("Let's talk this through.")
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
end
