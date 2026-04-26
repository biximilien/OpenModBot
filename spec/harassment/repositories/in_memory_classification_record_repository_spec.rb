require "harassment/repositories/in_memory_classification_record_repository"

describe Harassment::Repositories::InMemoryClassificationRecordRepository do
  subject(:repository) { described_class.new }

  let(:first_record) do
    Harassment::ClassificationRecord.build(
      server_id: 456,
      message_id: 123,
      classifier_version: "harassment-v1",
      model_version: "gpt-4o-2024-08-06",
      prompt_version: "harassment-prompt-v1",
      classification: {},
      severity_score: 0.4,
      confidence: 0.8,
      classified_at: Time.utc(2026, 4, 25, 14, 0, 0),
    )
  end

  let(:second_record) do
    Harassment::ClassificationRecord.build(
      server_id: 456,
      message_id: 123,
      classifier_version: "harassment-v2",
      model_version: "gpt-4o-2024-08-06",
      prompt_version: "harassment-prompt-v1",
      classification: { intent: "aggressive" },
      severity_score: 0.6,
      confidence: 0.9,
      classified_at: Time.utc(2026, 4, 25, 14, 5, 0),
    )
  end

  it "stores and retrieves records by message id and classifier version" do
    repository.save(first_record)

    found = repository.find(server_id: "456", message_id: "123", classifier_version: "harassment-v1")

    expect(found).to eq(first_record)
  end

  it "rejects duplicate records for the same message and classifier version" do
    repository.save(first_record)

    expect { repository.save(first_record) }.to raise_error(ArgumentError, "classification record already exists for 456:123:harassment-v1")
  end

  it "returns all records for a message ordered by classification time" do
    repository.save(second_record)
    repository.save(first_record)

    expect(repository.all_for_message(server_id: "456", message_id: "123")).to eq([first_record, second_record])
  end

  it "returns the latest record for a message" do
    repository.save(first_record)
    repository.save(second_record)

    expect(repository.latest_for_message(server_id: "456", message_id: "123")).to eq(second_record)
  end
end
