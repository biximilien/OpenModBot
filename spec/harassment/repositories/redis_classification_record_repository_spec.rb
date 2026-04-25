require "harassment/repositories/redis_classification_record_repository"
require_relative "../../support/fake_redis"

describe Harassment::Repositories::RedisClassificationRecordRepository do
  subject(:repository) { described_class.new(redis: redis) }

  let(:redis) { FakeRedis.new }
  let(:first_record) do
    Harassment::ClassificationRecord.build(
      server_id: 456,
      message_id: 123,
      classifier_version: "harassment-v1",
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
      classification: { intent: "aggressive" },
      severity_score: 0.6,
      confidence: 0.9,
      classified_at: Time.utc(2026, 4, 25, 14, 5, 0),
    )
  end

  it "stores and retrieves records by message id and classifier version" do
    repository.save(first_record)

    expect(repository.find(server_id: "456", message_id: "123", classifier_version: "harassment-v1")).to eq(first_record)
  end

  it "rejects duplicates and supports historical lookup" do
    repository.save(first_record)
    repository.save(second_record)

    expect { repository.save(first_record) }.to raise_error(ArgumentError, "classification record already exists for 456:123:harassment-v1")
    expect(repository.all_for_message(server_id: "456", message_id: "123")).to eq([first_record, second_record])
    expect(repository.latest_for_message(server_id: "456", message_id: "123")).to eq(second_record)
  end
end
