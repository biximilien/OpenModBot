require "discord"
require "discord/moderation_command"

describe Discord::ModerationCommand do
  let(:store) do
    instance_double(
      "Store",
      add_user_to_watch_list: true,
      remove_user_from_watch_list: true,
      get_watch_list_users: [456, 789],
      get_user_karma: -3,
      set_user_karma: 0,
      increment_user_karma: -2,
    )
  end
  let(:server) { instance_double("Server", id: 123, members: members) }
  let(:message) { instance_double("Message", content: content) }
  let(:user) { instance_double("User", id: 42, name: "Admin") }
  let(:event) { instance_double("Event", message: message, server: server, user: user, respond: true) }
  let(:admin_member) { instance_double("Member", id: 42, permission?: true) }
  let(:members) { [admin_member] }

  subject(:command) { described_class.new(store) }

  describe "#matches?" do
    context "with a moderation command" do
      let(:content) { "!moderation watchlist add <@456>" }

      it "returns true" do
        expect(command.matches?(event)).to eq(true)
      end
    end

    context "with a normal message" do
      let(:content) { "hello there" }

      it "returns false" do
        expect(command.matches?(event)).to eq(false)
      end
    end

    context "with a malformed moderation command" do
      let(:content) { "!moderation watchlist add" }

      it "returns true" do
        expect(command.matches?(event)).to eq(true)
      end
    end
  end

  describe "#handle" do
    context "when listing watched users" do
      let(:content) { "!moderation watchlist" }

      it "responds with user mentions" do
        command.handle(event)

        expect(event).to have_received(:respond).with("Watch list: <@456>, <@789>")
      end
    end

    context "when adding a watched user" do
      let(:content) { "!moderation watchlist add <@456>" }

      it "stores the user and responds" do
        command.handle(event)

        expect(store).to have_received(:add_user_to_watch_list).with(123, 456)
        expect(event).to have_received(:respond).with("Added <@456> to watch list")
      end
    end

    context "when removing a watched user" do
      let(:content) { "!moderation watchlist remove <@456>" }

      it "removes the user and responds" do
        command.handle(event)

        expect(store).to have_received(:remove_user_from_watch_list).with(123, 456)
        expect(event).to have_received(:respond).with("Removed <@456> from watch list")
      end
    end

    context "when the watchlist command is malformed" do
      let(:content) { "!moderation watchlist add" }

      it "responds with usage" do
        command.handle(event)

        expect(event).to have_received(:respond).with(described_class::USAGE)
      end
    end

    context "when checking user karma" do
      let(:content) { "!moderation karma <@456>" }

      it "responds with the user's karma score" do
        command.handle(event)

        expect(store).to have_received(:get_user_karma).with(123, 456)
        expect(event).to have_received(:respond).with("Karma for <@456>: -3")
      end
    end

    context "when resetting user karma" do
      let(:content) { "!moderation karma reset <@456>" }

      it "resets the user's karma score" do
        command.handle(event)

        expect(store).to have_received(:set_user_karma).with(123, 456, 0)
        expect(event).to have_received(:respond).with("Reset karma for <@456>")
      end
    end

    context "when adding user karma" do
      let(:content) { "!moderation karma add <@456> 2" }

      it "increases the user's karma score" do
        command.handle(event)

        expect(store).to have_received(:increment_user_karma).with(123, 456, 2)
        expect(event).to have_received(:respond).with("Karma for <@456>: -2")
      end
    end

    context "when removing user karma" do
      let(:content) { "!moderation karma remove <@456> 2" }

      it "decreases the user's karma score" do
        command.handle(event)

        expect(store).to have_received(:increment_user_karma).with(123, 456, -2)
        expect(event).to have_received(:respond).with("Karma for <@456>: -2")
      end
    end

    context "when adjusting karma by zero" do
      let(:content) { "!moderation karma add <@456> 0" }

      it "responds with usage" do
        command.handle(event)

        expect(event).to have_received(:respond).with(described_class::USAGE)
      end
    end

    context "when checking karma without a user" do
      let(:content) { "!moderation karma" }

      it "responds with usage" do
        command.handle(event)

        expect(event).to have_received(:respond).with(described_class::USAGE)
      end
    end

    context "when the user is not an administrator" do
      let(:content) { "!moderation watchlist" }
      let(:admin_member) { instance_double("Member", id: 42, permission?: false) }

      it "does not respond or mutate state" do
        command.handle(event)

        expect(event).not_to have_received(:respond)
        expect(store).not_to have_received(:get_watch_list_users)
      end
    end
  end
end
