require "harassment/classification/record"

describe Harassment::ClassificationRecord do
  it "builds a normalized classification record" do
    classified_at = Time.utc(2026, 4, 25, 12, 30, 0)

    record = described_class.build(
      server_id: 456,
      message_id: 123,
      classifier_version: "harassment-v1",
      model_version: "gpt-4o-2024-08-06",
      prompt_version: "harassment-prompt-v1",
      classification: {
        intent: "aggressive",
        target_type: "individual",
        categories: { insult: true, threat: false },
      },
      severity_score: 0.8,
      confidence: 0.9,
      classified_at: classified_at,
    )

    expect(record.message_id).to eq("123")
    expect(record.classifier_version).to eq(Harassment::ClassifierVersion.build("harassment-v1"))
    expect(record.model_version).to eq("gpt-4o-2024-08-06")
    expect(record.prompt_version).to eq("harassment-prompt-v1")
    expect(record.severity_score).to eq(0.8)
    expect(record.confidence).to eq(0.9)
    expect(record.classified_at).to eq(classified_at)
  end

  it "requires identity and lineage fields" do
    expect do
      described_class.build(
        message_id: 123,
        classifier_version: "harassment-v1",
        classification: {},
        severity_score: 0.4,
        confidence: 0.5,
      )
    end.to raise_error(ArgumentError, /missing keywords: :server_id, :model_version, :prompt_version/)
  end

  it "rejects scores outside the 0..1 range" do
    expect do
      described_class.build(
        server_id: 456,
        message_id: 123,
        classifier_version: "harassment-v1",
        model_version: "gpt-4o-2024-08-06",
        prompt_version: "harassment-prompt-v1",
        classification: {},
        severity_score: 1.5,
        confidence: 0.5,
      )
    end.to raise_error(ArgumentError, "severity_score must be between 0.0 and 1.0")
  end

  it "rejects empty lineage fields" do
    expect do
      described_class.build(
        server_id: 456,
        message_id: 123,
        classifier_version: "harassment-v1",
        model_version: " ",
        prompt_version: "harassment-prompt-v1",
        classification: {},
        severity_score: 0.4,
        confidence: 0.5,
      )
    end.to raise_error(ArgumentError, "model_version must not be empty")
  end
end
