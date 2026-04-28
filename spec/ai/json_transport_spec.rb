require "ai/json_transport"
require "net/http"

describe ModerationGPT::AI::JsonTransport do
  subject(:transport) do
    described_class.new(
      provider_name: "Test AI",
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer test-key",
      },
    )
  end

  let(:span) { instance_double("Span", add_event: true, set_attribute: true) }
  let(:http) { instance_double("Net::HTTP") }
  let(:response) { instance_double(Net::HTTPSuccess, body: '{"ok":true}', code: "200", is_a?: true) }
  let(:user) { instance_double("User", id: 123, bot_account: false) }

  before do
    allow(Telemetry).to receive(:in_span).and_yield(span)
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:request).and_return(response)
  end

  it "posts JSON with configured headers and returns parsed JSON" do
    result = transport.post(url: "https://example.test/v1/test", payload: { input: "hello" }, user:)

    request = request_sent_to_http
    expect(result).to eq("ok" => true)
    expect(request["Content-Type"]).to eq("application/json")
    expect(request["Authorization"]).to eq("Bearer test-key")
    expect(request.body).to eq('{"input":"hello"}')
  end

  it "records common telemetry attributes" do
    transport.post(url: "https://example.test/v1/test", payload: {}, user:)

    expect(Telemetry).to have_received(:in_span).with(
      "https://example.test/v1/test",
      attributes: hash_including(
        "http.method" => "POST",
        "http.target" => "/v1/test",
        "net.peer.name" => "example.test",
        "discord.user.hash" => Telemetry::Anonymizer.hash(123),
        "discord.user.bot_account" => false,
      ),
    )
    expect(span).to have_received(:set_attribute).with("http.status_code", 200)
  end

  it "raises provider-scoped errors for invalid JSON" do
    allow(response).to receive(:body).and_return("not json")

    expect do
      transport.post(url: "https://example.test/v1/test", payload: {})
    end.to raise_error(RuntimeError, "Test AI API returned invalid JSON")
  end

  def request_sent_to_http
    sent_request = nil
    expect(http).to have_received(:request) { |request| sent_request = request }
    sent_request
  end
end
