require "backend"
require "json"

describe Backend do
  include described_class

  let(:server_id) { 123 }
  let(:user_id) { 456 }

  before do
    initialize_backend
  end

  describe "#add_user_to_watch_list" do
    it "adds a user to the watch list" do
      add_user_to_watch_list(server_id, user_id)
      expect(get_watch_list_users(server_id)).to include(user_id)
    end
  end

  describe "#remove_user_from_watch_list" do
    it "removes a user from the watch list" do
      add_user_to_watch_list(server_id, user_id)
      remove_user_from_watch_list(server_id, user_id)
      expect(get_watch_list_users(server_id)).not_to include(user_id)
    end
  end

  describe "#get_watch_list_users" do
    it "returns the watch list users" do
      add_user_to_watch_list(server_id, user_id)
      expect(get_watch_list_users(server_id)).to eq([user_id])
    end
  end

  describe "#get_user_karma" do
    it "returns zero for users without karma events" do
      expect(get_user_karma(server_id, user_id)).to eq(0)
    end
  end

  describe "#decrement_user_karma" do
    it "decrements a user's karma score" do
      expect(decrement_user_karma(server_id, user_id)).to eq(-1)
      expect(get_user_karma(server_id, user_id)).to eq(-1)
    end

    it "supports custom decrement amounts" do
      expect(decrement_user_karma(server_id, user_id, 3)).to eq(-3)
      expect(get_user_karma(server_id, user_id)).to eq(-3)
    end

    it "records an audit event" do
      decrement_user_karma(server_id, user_id, 2, reason: "moderation_flag")

      expect(get_user_karma_history(server_id, user_id)).to include(
        hash_including(delta: -2, score: -2, source: "automated_infraction", reason: "moderation_flag")
      )
    end

    it "rejects non-positive amounts" do
      expect { decrement_user_karma(server_id, user_id, 0) }.to raise_error(ArgumentError, "amount must be positive")
      expect { decrement_user_karma(server_id, user_id, -1) }.to raise_error(ArgumentError, "amount must be positive")
    end
  end

  describe "#increment_user_karma" do
    it "increments a user's karma score" do
      expect(increment_user_karma(server_id, user_id, 2)).to eq(2)
      expect(get_user_karma(server_id, user_id)).to eq(2)
    end

    it "records manual adjustment metadata" do
      increment_user_karma(server_id, user_id, 2, actor_id: 99)

      expect(get_user_karma_history(server_id, user_id)).to include(
        hash_including(delta: 2, score: 2, source: "manual_adjustment", actor_id: 99)
      )
    end

    it "rejects non-positive amounts" do
      expect { increment_user_karma(server_id, user_id, 0) }.to raise_error(ArgumentError, "amount must be positive")
      expect { increment_user_karma(server_id, user_id, -1) }.to raise_error(ArgumentError, "amount must be positive")
    end
  end

  describe "#set_user_karma" do
    it "sets a user's karma score" do
      expect(set_user_karma(server_id, user_id, 10)).to eq(10)
      expect(get_user_karma(server_id, user_id)).to eq(10)
    end

    it "records the delta from the previous score" do
      increment_user_karma(server_id, user_id, 3)
      set_user_karma(server_id, user_id, 0, actor_id: 99)

      expect(get_user_karma_history(server_id, user_id).first).to include(
        delta: -3,
        score: 0,
        source: "manual_reset",
        actor_id: 99
      )
    end

    it "rejects non-integer scores" do
      expect { set_user_karma(server_id, user_id, "abc") }.to raise_error(ArgumentError, "score must be an integer")
    end
  end

  describe "#record_user_karma_event" do
    it "records a zero-delta audit event without changing the score" do
      set_user_karma(server_id, user_id, -5)
      record_user_karma_event(server_id, user_id, score: -5, source: "automod_timeout_applied")

      expect(get_user_karma(server_id, user_id)).to eq(-5)
      expect(get_user_karma_history(server_id, user_id).first).to include(
        delta: 0,
        score: -5,
        source: "automod_timeout_applied"
      )
    end

    it "rejects non-integer score or delta values" do
      expect do
        record_user_karma_event(server_id, user_id, score: "abc",
                                                    source: "event")
      end.to raise_error(ArgumentError, "score must be an integer")
      expect do
        record_user_karma_event(server_id, user_id, score: -5, source: "event",
                                                    delta: "abc")
      end.to raise_error(ArgumentError, "delta must be an integer")
    end
  end

  describe "#get_user_karma_history" do
    it "returns the most recent events first" do
      increment_user_karma(server_id, user_id, 1)
      decrement_user_karma(server_id, user_id, 2)

      expect(get_user_karma_history(server_id, user_id).map { |entry| entry[:delta] }).to eq([-2, 1])
    end

    it "honors the requested limit" do
      increment_user_karma(server_id, user_id, 1)
      increment_user_karma(server_id, user_id, 2)

      expect(get_user_karma_history(server_id, user_id, 1).length).to eq(1)
    end

    it "normalizes invalid limits" do
      increment_user_karma(server_id, user_id, 1)

      expect(get_user_karma_history(server_id, user_id, 0).length).to eq(1)
    end
  end

  describe "#add_server" do
    it "adds a server" do
      add_server(server_id)
      expect(servers).to include(server_id)
    end
  end

  describe "#remove_server" do
    it "removes a server" do
      add_server(server_id)
      remove_server(server_id)
      expect(servers).not_to include(server_id)
    end

    it "purges the server's moderation data" do
      add_server(server_id)
      add_user_to_watch_list(server_id, user_id)
      increment_user_karma(server_id, user_id, 2)
      record_user_karma_event(server_id, user_id, score: 2, source: "manual_note")

      remove_server(server_id)

      expect(get_watch_list_users(server_id)).to eq([])
      expect(get_user_karma(server_id, user_id)).to eq(0)
      expect(get_user_karma_history(server_id, user_id)).to eq([])
    end

    it "does not purge data from other servers" do
      other_server_id = 999
      add_server(server_id)
      add_server(other_server_id)
      increment_user_karma(server_id, user_id, 1)
      increment_user_karma(other_server_id, user_id, 3)

      remove_server(server_id)

      expect(servers).to include(other_server_id)
      expect(get_user_karma(other_server_id, user_id)).to eq(3)
      expect(get_user_karma_history(other_server_id, user_id).first).to include(score: 3)
    end
  end

  describe "#servers" do
    it "returns the servers" do
      add_server(server_id)
      expect(servers).to eq([server_id])
    end
  end
end
