require "open_ai/transport"

describe OpenAI::Transport do
  let(:json_transport) { instance_double(OpenModBot::AI::JsonTransport, post: { "ok" => true }) }

  before do
    allow(OpenModBot::AI::JsonTransport).to receive(:new).and_return(json_transport)
  end

  it "configures shared JSON transport with OpenAI headers" do
    described_class.new(api_key: "test-key")

    expect(OpenModBot::AI::JsonTransport).to have_received(:new).with(
      provider_name: "OpenAI",
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer test-key"
      }
    )
  end

  it "delegates OpenAI queries to shared JSON transport" do
    user = instance_double("User")
    result = described_class.new(api_key: "test-key").query("https://api.openai.com/v1/test", { input: "hello" }, user)

    expect(result).to eq("ok" => true)
    expect(json_transport).to have_received(:post).with(
      url: "https://api.openai.com/v1/test",
      payload: { input: "hello" },
      user:
    )
  end
end
