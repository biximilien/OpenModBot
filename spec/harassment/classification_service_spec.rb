require "harassment/classification/service"

describe Harassment::ClassificationService do
  let(:event) do
    Harassment::InteractionEvent.build(
      message_id: 123,
      server_id: 456,
      channel_id: 789,
      author_id: 321,
      target_user_ids: [654],
      raw_content: "hello there",
    )
  end
  let(:record) do
    Harassment::ClassificationRecord.build(
      server_id: "456",
      message_id: 123,
      classifier_version: "harassment-v1",
      model_version: "gpt-4o-2024-08-06",
      prompt_version: "harassment-prompt-v1",
      classification: { intent: "aggressive", target_type: "individual" },
      severity_score: 0.8,
      confidence: 0.5,
      classified_at: Time.utc(2026, 4, 25, 16, 0, 0),
    )
  end

  subject(:service) { described_class.new }

  it "records classifications into its read model" do
    incident = service.record(event:, record:)

    expect(incident.intent).to eq("aggressive")
    expect(service.read_model.recent_incidents("456", "789")).to eq([incident])
  end

  it "exposes classifier identity and construction" do
    client = instance_double("OpenAIClient")

    expect(service.classifier_version).to eq("harassment-v1")
    expect(service.prompt_version).to eq("harassment-prompt-v1")
    expect(service.build_classifier(client:, model: "gpt-4o-test")).to be_a(Harassment::OpenAIClassifier)
  end
end
