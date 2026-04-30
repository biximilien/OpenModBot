RSpec.shared_examples "a moderation store" do
  let(:server_id) { 123 }
  let(:other_server_id) { 999 }
  let(:user_id) { 456 }

  it "stores and removes watchlist users" do
    store.add_user_to_watch_list(server_id, user_id)

    expect(store.get_watch_list_users(server_id)).to eq([user_id])

    store.remove_user_from_watch_list(server_id, user_id)

    expect(store.get_watch_list_users(server_id)).to eq([])
  end

  it "stores known servers" do
    store.add_server(server_id)

    expect(store.servers).to eq([server_id])

    store.remove_server(server_id)

    expect(store.servers).to eq([])
  end

  it "tracks karma scores and audit history" do
    expect(store.get_user_karma(server_id, user_id)).to eq(0)

    expect(store.increment_user_karma(server_id, user_id, 2, actor_id: 42)).to eq(2)
    expect(store.decrement_user_karma(server_id, user_id, 1, reason: "flag")).to eq(1)
    expect(store.set_user_karma(server_id, user_id, -5, actor_id: 42)).to eq(-5)
    store.record_user_karma_event(server_id, user_id, score: -5, source: "automod_timeout_applied")

    expect(store.get_user_karma(server_id, user_id)).to eq(-5)
    expect(store.get_user_karma_history(server_id, user_id, 4)).to match(
      [
        hash_including(delta: 0, score: -5, source: "automod_timeout_applied"),
        hash_including(delta: -6, score: -5, source: "manual_reset", actor_id: 42),
        hash_including(delta: -1, score: 1, source: "automated_infraction", reason: "flag"),
        hash_including(delta: 2, score: 2, source: "manual_adjustment", actor_id: 42)
      ]
    )
  end

  it "validates karma inputs consistently" do
    expect { store.increment_user_karma(server_id, user_id, 0) }
      .to raise_error(ArgumentError, "amount must be positive")
    expect { store.decrement_user_karma(server_id, user_id, -1) }
      .to raise_error(ArgumentError, "amount must be positive")
    expect { store.set_user_karma(server_id, user_id, "abc") }
      .to raise_error(ArgumentError, "score must be an integer")
    expect { store.record_user_karma_event(server_id, user_id, score: "abc", source: "manual_note") }
      .to raise_error(ArgumentError, "score must be an integer")
  end

  it "stores, filters, finds, and clears moderation reviews" do
    first = store.record_moderation_review(
      server_id: server_id,
      channel_id: 11,
      message_id: 22,
      user_id: user_id,
      strategy: "RemoveMessageStrategy",
      action: "removed",
      shadow_mode: false,
      flagged: true,
      categories: { harassment: true },
      category_scores: { harassment: 0.9 },
      original_content: "bad message"
    )
    store.record_moderation_review(
      server_id: server_id,
      channel_id: 11,
      message_id: 33,
      user_id: 777,
      strategy: "WatchListStrategy",
      action: "rewrote",
      shadow_mode: true,
      flagged: false
    )

    expect(first).to include(message_id: "22", user_id: user_id.to_s, original_content: "bad message")
    expect(store.get_moderation_reviews(server_id, 10).map { |entry| entry[:message_id] }).to eq(%w[33 22])
    expect(store.get_moderation_reviews(server_id, 10, user_id: user_id).map { |entry| entry[:message_id] })
      .to eq(["22"])
    expect(store.find_moderation_review(server_id, 22)).to include(message_id: "22")

    store.clear_moderation_reviews(server_id)

    expect(store.get_moderation_reviews(server_id)).to eq([])
  end

  it "purges only the removed server's moderation data" do
    store.add_server(server_id)
    store.add_server(other_server_id)
    store.add_user_to_watch_list(server_id, user_id)
    store.increment_user_karma(server_id, user_id, 1)
    store.increment_user_karma(other_server_id, user_id, 3)
    store.record_moderation_review(
      server_id: server_id,
      channel_id: 11,
      message_id: 22,
      user_id: user_id,
      strategy: "Strategy",
      action: "removed",
      shadow_mode: false,
      flagged: true
    )

    store.remove_server(server_id)

    expect(store.servers).to eq([other_server_id])
    expect(store.get_watch_list_users(server_id)).to eq([])
    expect(store.get_user_karma(server_id, user_id)).to eq(0)
    expect(store.get_user_karma_history(server_id, user_id)).to eq([])
    expect(store.get_moderation_reviews(server_id)).to eq([])
    expect(store.get_user_karma(other_server_id, user_id)).to eq(3)
  end
end
