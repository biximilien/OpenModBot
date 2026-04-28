require "backend"
require_relative "../support/fake_redis"

describe Backend::ModerationReviewStore do
  include Backend

  let(:server_id) { 123 }
  let(:user_id) { 456 }

  before do
    allow(Redis).to receive(:new).and_return(FakeRedis.new)
    initialize_backend
  end

  it "records recent moderation reviews" do
    record_moderation_review(
      server_id: server_id,
      channel_id: 789,
      message_id: 111,
      user_id: user_id,
      strategy: "RemoveMessageStrategy",
      action: "removed",
      shadow_mode: false,
      flagged: true,
      categories: { "harassment" => true },
    )

    expect(get_moderation_reviews(server_id)).to include(
      hash_including(
        schema_version: 1,
        server_id: "123",
        channel_id: "789",
        message_id: "111",
        user_id: "456",
        strategy: "RemoveMessageStrategy",
        action: "removed",
        shadow_mode: false,
        flagged: true,
        categories: { harassment: true },
      ),
    )
  end

  it "filters moderation reviews by user" do
    record_moderation_review(server_id: server_id, channel_id: 1, message_id: 1, user_id: user_id, strategy: "A", action: "removed", shadow_mode: false, flagged: true)
    record_moderation_review(server_id: server_id, channel_id: 1, message_id: 2, user_id: 999, strategy: "A", action: "removed", shadow_mode: false, flagged: true)

    expect(get_moderation_reviews(server_id, 5, user_id: user_id).map { |entry| entry[:user_id] }).to eq(["456"])
  end

  it "finds a moderation review by message id" do
    record_moderation_review(server_id: server_id, channel_id: 1, message_id: 1234, user_id: user_id, strategy: "A", action: "removed", shadow_mode: false, flagged: true)

    expect(find_moderation_review(server_id, 1234)).to include(message_id: "1234")
  end

  it "clears moderation reviews when removing a server" do
    record_moderation_review(server_id: server_id, channel_id: 1, message_id: 1, user_id: user_id, strategy: "A", action: "removed", shadow_mode: false, flagged: true)
    add_server(server_id)

    remove_server(server_id)

    expect(get_moderation_reviews(server_id)).to eq([])
  end
end
