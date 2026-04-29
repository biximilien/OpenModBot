require "google_ai/transport"

describe GoogleAI::Transport do
  let(:json_transport) { instance_double(OpenModBot::AI::JsonTransport, post: { "ok" => true }) }

  before do
    allow(OpenModBot::AI::JsonTransport).to receive(:new).and_return(json_transport)
  end

  it "configures shared JSON transport with Google AI headers" do
    described_class.new(api_key: "google-key")

    expect(OpenModBot::AI::JsonTransport).to have_received(:new).with(
      provider_name: "Google AI",
      headers: {
        "Content-Type" => "application/json",
        "x-goog-api-key" => "google-key"
      }
    )
  end

  it "delegates generateContent calls to shared JSON transport" do
    user = instance_double("User")
    result = described_class.new(api_key: "google-key").generate_content(model: "gemini-test",
                                                                         payload: { contents: [] }, user:)

    expect(result).to eq("ok" => true)
    expect(json_transport).to have_received(:post).with(
      url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-test:generateContent",
      payload: { contents: [] },
      user:
    )
  end
end
