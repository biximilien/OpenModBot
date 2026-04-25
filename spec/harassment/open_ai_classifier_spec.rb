require "harassment/open_ai_classifier"

describe Harassment::OpenAIClassifier do
  let(:client) { instance_double("OpenAIClient") }
  let(:event) do
    Harassment::InteractionEvent.build(
      message_id: 123,
      server_id: 456,
      channel_id: 789,
      author_id: 321,
      target_user_ids: [654],
      timestamp: Time.utc(2026, 4, 25, 18, 0, 0),
      raw_content: "you're not welcome here",
    )
  end

  subject(:classifier) { described_class.new(client: client, model: "gpt-4o-2024-08-06") }

  it "builds a classification record from structured OpenAI output" do
    response = { "output_text" => <<~JSON.strip }
      {"intent":"aggressive","target_type":"individual","toxicity_dimensions":{"insult":true,"threat":false,"profanity":false,"exclusion":true,"harassment":true},"severity_score":0.8,"confidence":0.9}
    JSON
    allow(client).to receive(:query).and_return(response)
    allow(client).to receive(:response_text).with(response).and_return(response["output_text"])

    record = classifier.classify(
      event: event,
      classifier_version: "harassment-v1",
      classified_at: Time.utc(2026, 4, 25, 18, 1, 0),
    )

    expect(record.message_id).to eq("123")
    expect(record.classifier_version).to eq(Harassment::ClassifierVersion.build("harassment-v1"))
    expect(record.classification).to eq(
      intent: "aggressive",
      target_type: "individual",
      toxicity_dimensions: {
        insult: true,
        threat: false,
        profanity: false,
        exclusion: true,
        harassment: true,
      },
    )
    expect(record.severity_score).to eq(0.8)
    expect(record.confidence).to eq(0.9)
    expect(record.classified_at).to eq(Time.utc(2026, 4, 25, 18, 1, 0))
    expect(client).to have_received(:query).with(
      "https://api.openai.com/v1/responses",
      hash_including(
        model: "gpt-4o-2024-08-06",
        input: a_string_including("\"recent_channel_messages\":[]", "\"recent_pair_interactions\":[]"),
        text: hash_including(
          format: hash_including(
            type: "json_schema",
            name: "harassment_classification",
            strict: true,
          ),
        ),
      ),
    )
  end

  it "uses pseudonymous participant labels in classifier input" do
    response = { "output_text" => <<~JSON.strip }
      {"intent":"aggressive","target_type":"individual","toxicity_dimensions":{"insult":true,"threat":false,"profanity":false,"exclusion":true,"harassment":true},"severity_score":0.8,"confidence":0.9}
    JSON
    allow(client).to receive(:query).and_return(response)
    allow(client).to receive(:response_text).with(response).and_return(response["output_text"])

    classifier.classify(
      event: event,
      classifier_version: "harassment-v1",
      context: {
        participant_labels: {
          "321" => "author",
          "654" => "target_1",
          "999" => "participant_3",
        },
        recent_channel_messages: [
          {
            timestamp: "2026-04-25T17:59:00Z",
            author_label: "participant_3",
            target_labels: ["author"],
            content: "calm down",
          },
        ],
        recent_pair_interactions: [],
      },
    )

    expect(client).to have_received(:query).with(
      "https://api.openai.com/v1/responses",
      hash_including(
        input: a_string_including("\"author_label\":\"author\"", "\"target_labels\":[\"target_1\"]", "\"participant_3\""),
      ),
    )
    expect(client).not_to have_received(:query).with(
      anything,
      hash_including(input: a_string_including("\"321\"", "\"654\"", "\"999\"")),
    )
  end

  it "raises a terminal validation error when OpenAI returns invalid JSON" do
    response = { "output_text" => "definitely not json" }
    allow(client).to receive(:query).and_return(response)
    allow(client).to receive(:response_text).with(response).and_return(response["output_text"])

    expect do
      classifier.classify(event: event, classifier_version: "harassment-v1")
    end.to raise_error(ArgumentError, /returned invalid JSON/)
  end
end
