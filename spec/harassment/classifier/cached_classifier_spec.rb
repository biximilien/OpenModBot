require "harassment/classifier/cached_classifier"
require "harassment/repositories/in_memory_classification_cache_repository"

describe Harassment::CachedClassifier do
  subject(:classifier) do
    described_class.new(
      delegate: delegate,
      cache_repository: cache_repository,
      ttl_seconds: 3_600
    )
  end

  let(:delegate) do
    instance_double("Classifier", cache_identity: { model_version: "gpt-4o", prompt_version: "harassment-prompt-v1" })
  end
  let(:cache_repository) { Harassment::Repositories::InMemoryClassificationCacheRepository.new }
  let(:event) do
    Harassment::InteractionEvent.build(
      message_id: 123,
      server_id: 456,
      channel_id: 789,
      author_id: 321,
      target_user_ids: [654],
      raw_content: "leave them alone"
    )
  end
  let(:context) do
    {
      participant_labels: { "321" => "author", "654" => "target_1" },
      recent_channel_messages: [{ author_label: "target_1", content: "please stop" }],
      recent_pair_interactions: []
    }
  end
  let(:record) do
    Harassment::ClassificationRecord.build(
      server_id: "456",
      message_id: "123",
      classifier_version: "harassment-v1",
      model_version: "gpt-4o",
      prompt_version: "harassment-prompt-v1",
      classification: { intent: "aggressive", target_type: "individual", toxicity_dimensions: {} },
      severity_score: 0.8,
      confidence: 0.9,
      classified_at: Time.utc(2026, 4, 25, 18, 0, 0)
    )
  end

  it "reuses cached classifications for the same server, classifier, content, and context" do
    allow(delegate).to receive(:classify).and_return(record)

    first = classifier.classify(
      event: event,
      classifier_version: "harassment-v1",
      context: context,
      classified_at: Time.utc(2026, 4, 25, 18, 0, 0)
    )
    second_event = event.with(message_id: "124")
    second = classifier.classify(
      event: second_event,
      classifier_version: "harassment-v1",
      context: context,
      classified_at: Time.utc(2026, 4, 25, 18, 1, 0)
    )

    expect(first).to eq(record)
    expect(second).to eq(record)
    expect(delegate).to have_received(:classify).once
  end

  it "does not reuse cached classifications across servers" do
    allow(delegate).to receive(:classify).and_return(record, record.with(server_id: "999", message_id: "123"))

    classifier.classify(
      event: event,
      classifier_version: "harassment-v1",
      context: context,
      classified_at: Time.utc(2026, 4, 25, 18, 0, 0)
    )
    classifier.classify(
      event: event.with(server_id: "999"),
      classifier_version: "harassment-v1",
      context: context,
      classified_at: Time.utc(2026, 4, 25, 18, 1, 0)
    )

    expect(delegate).to have_received(:classify).twice
  end
end
