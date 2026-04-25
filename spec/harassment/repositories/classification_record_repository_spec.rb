require "harassment/repositories/classification_record_repository"

describe Harassment::Repositories::ClassificationRecordRepository do
  subject(:repository) { described_class.new }

  let(:record) do
    Harassment::ClassificationRecord.build(
      server_id: 456,
      message_id: 123,
      classifier_version: "harassment-v1",
      classification: {},
      severity_score: 0.4,
      confidence: 0.8,
    )
  end

  it "requires subclasses to implement #save" do
    expect { repository.save(record) }.to raise_error(NotImplementedError, /must implement #save/)
  end

  it "requires subclasses to implement #find" do
    expect do
      repository.find(server_id: "456", message_id: "123", classifier_version: "harassment-v1")
    end.to raise_error(NotImplementedError, /must implement #find/)
  end

  it "requires subclasses to implement #all_for_message" do
    expect { repository.all_for_message(server_id: "456", message_id: "123") }.to raise_error(NotImplementedError, /must implement #all_for_message/)
  end

  it "requires subclasses to implement #latest_for_message" do
    expect { repository.latest_for_message(server_id: "456", message_id: "123") }.to raise_error(NotImplementedError, /must implement #latest_for_message/)
  end
end
