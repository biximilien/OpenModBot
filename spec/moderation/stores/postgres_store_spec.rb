require "moderation/stores/postgres_store"
require_relative "../../support/fake_postgres_connection"
require_relative "../../support/shared_examples/moderation_store_contract"

describe Moderation::Stores::PostgresStore do
  subject(:store) { described_class.new(connection:) }

  let(:connection) { FakePostgresConnection.new }
  let(:server_id) { 123 }
  let(:user_id) { 456 }

  it_behaves_like "a moderation store"

  it "stores watchlists, karma, servers, and reviews in Postgres" do
    store.add_server(server_id)
    store.add_user_to_watch_list(server_id, user_id)
    store.increment_user_karma(server_id, user_id, 2, actor_id: 99)
    store.record_moderation_review(
      server_id: server_id,
      channel_id: 1,
      message_id: 2,
      user_id: user_id,
      strategy: "Strategy",
      action: "removed",
      shadow_mode: false,
      flagged: true
    )

    expect(store.servers).to eq([server_id])
    expect(store.get_watch_list_users(server_id)).to eq([user_id])
    expect(store.get_user_karma(server_id, user_id)).to eq(2)
    expect(store.get_user_karma_history(server_id, user_id).first).to include(
      score: 2,
      delta: 2,
      actor_id: 99
    )
    expect(store.find_moderation_review(server_id, 2)).to include(
      message_id: "2",
      user_id: user_id.to_s
    )
  end

  it "purges moderation data when a server is removed" do
    store.add_server(server_id)
    store.add_user_to_watch_list(server_id, user_id)
    store.set_user_karma(server_id, user_id, 5)
    store.record_moderation_review(
      server_id: server_id,
      channel_id: 1,
      message_id: 2,
      user_id: user_id,
      strategy: "Strategy",
      action: "removed",
      shadow_mode: false,
      flagged: true
    )

    store.remove_server(server_id)

    expect(store.servers).to eq([])
    expect(store.get_watch_list_users(server_id)).to eq([])
    expect(store.get_user_karma(server_id, user_id)).to eq(0)
    expect(store.get_user_karma_history(server_id, user_id)).to eq([])
    expect(store.get_moderation_reviews(server_id)).to eq([])
  end
end
