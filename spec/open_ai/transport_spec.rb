require "net/http"
require "open_ai/transport"

describe OpenAI::Transport do
  subject(:transport) { described_class.new(api_key: "test-key") }

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

  it "posts JSON with authorization and returns parsed JSON" do
    result = transport.query("https://api.openai.com/v1/test", { input: "hello" }, user)

    request = request_sent_to_http
    expect(result).to eq("ok" => true)
    expect(request["Content-Type"]).to eq("application/json")
    expect(request["Authorization"]).to eq("Bearer test-key")
    expect(request.body).to eq('{"input":"hello"}')
  end

  it "records telemetry attributes for the OpenAI request" do
    transport.query("https://api.openai.com/v1/test", {}, user)

    expect(Telemetry).to have_received(:in_span).with(
      "https://api.openai.com/v1/test",
      attributes: hash_including(
        "http.method" => "POST",
        "http.target" => "/v1/test",
        "net.peer.name" => "api.openai.com",
        "discord.user.hash" => Telemetry::Anonymizer.hash(123),
        "discord.user.bot_account" => false,
      ),
    )
    expect(span).to have_received(:set_attribute).with("http.status_code", 200)
  end

  it "raises a normalized error when OpenAI returns invalid JSON" do
    allow(response).to receive(:body).and_return("not json")

    expect { transport.query("https://api.openai.com/v1/test", {}) }.to raise_error(
      RuntimeError,
      "OpenAI API returned invalid JSON",
    )
  end

  it "raises a normalized error when the request times out" do
    allow(http).to receive(:request).and_raise(Net::ReadTimeout)

    expect { transport.query("https://api.openai.com/v1/test", {}) }.to raise_error(
      RuntimeError,
      "OpenAI API timeout",
    )
  end

  def request_sent_to_http
    sent_request = nil
    expect(http).to have_received(:request) do |request|
      sent_request = request
    end
    sent_request
  end
end
