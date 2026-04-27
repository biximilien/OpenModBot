require "harassment/repositories/interaction_event_repository"

describe Harassment::Repositories::InteractionEventRepository do
  subject(:repository) { described_class.new }

  let(:event) do
    Harassment::InteractionEvent.build(
      message_id: 123,
      server_id: 456,
      channel_id: 789,
      author_id: 321,
      raw_content: "hello there",
    )
  end

  it "requires subclasses to implement #save" do
    expect { repository.save(event) }.to raise_error(NotImplementedError, /must implement #save/)
  end

  it "requires subclasses to implement #find" do
    expect { repository.find("123", server_id: "456") }.to raise_error(NotImplementedError, /must implement #find/)
  end

  it "requires subclasses to implement #update_classification_status" do
    expect do
      repository.update_classification_status("123", Harassment::ClassificationStatus::CLASSIFIED, server_id: "456")
    end.to raise_error(NotImplementedError, /must implement #update_classification_status/)
  end

  it "requires subclasses to implement #list_by_classification_status" do
    expect { repository.list_by_classification_status(Harassment::ClassificationStatus::PENDING) }.to raise_error(NotImplementedError, /must implement #list_by_classification_status/)
  end

  it "requires subclasses to implement #list_classified_for_server" do
    expect { repository.list_classified_for_server("456") }.to raise_error(NotImplementedError, /must implement #list_classified_for_server/)
  end

  it "requires subclasses to implement #list_with_expired_content" do
    expect { repository.list_with_expired_content }.to raise_error(NotImplementedError, /must implement #list_with_expired_content/)
  end

  it "requires subclasses to implement #redact_content" do
    expect { repository.redact_content("123", server_id: "456") }.to raise_error(NotImplementedError, /must implement #redact_content/)
  end

  it "requires subclasses to implement #recent_in_channel" do
    expect do
      repository.recent_in_channel(server_id: "456", channel_id: "789", before: Time.utc(2026, 4, 25, 12, 0, 0), limit: 2)
    end.to raise_error(NotImplementedError, /must implement #recent_in_channel/)
  end

  it "requires subclasses to implement #recent_between_participants" do
    expect do
      repository.recent_between_participants(
        server_id: "456",
        participant_ids: %w[321 654],
        before: Time.utc(2026, 4, 25, 12, 0, 0),
        limit: 2,
      )
    end.to raise_error(NotImplementedError, /must implement #recent_between_participants/)
  end
end
