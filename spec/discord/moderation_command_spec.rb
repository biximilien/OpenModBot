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
      get_user_karma_history: [
        { created_at: "2026-04-19T12:00:00Z", delta: -1, score: -3, source: "automated_infraction" },
        { created_at: "2026-04-19T12:05:00Z", delta: 2, score: -2, source: "manual_adjustment", actor_id: 42 },
      ],
      set_user_karma: -7,
      increment_user_karma: -2,
      decrement_user_karma: -2,
    )
  end
  let(:server) { instance_double("Server", id: 123, members: members) }
  let(:message) { instance_double("Message", content: content) }
  let(:user) { instance_double("User", id: 42, name: "Admin") }
  let(:event) { instance_double("Event", message: message, server: server, user: user, respond: true) }
  let(:admin_member) { instance_double("Member", id: 42, permission?: true) }
  let(:members) { [admin_member] }
  let(:plugin_command) do
    instance_double(
      "PluginCommand",
      matches?: false,
      handle: true,
      help_lines: ["!moderation plugin"],
    )
  end

  subject(:command) { described_class.new(store, plugin_commands: [plugin_command]) }

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
    context "when requesting help" do
      let(:content) { "!moderation help" }

      it "responds with available commands" do
        command.handle(event)

        expect(event).to have_received(:respond).with("#{described_class::HELP_TEXT}\n!moderation plugin")
      end
    end

    context "when requesting moderation without a subcommand" do
      let(:content) { "!moderation" }

      it "responds with available commands" do
        command.handle(event)

        expect(event).to have_received(:respond).with("#{described_class::HELP_TEXT}\n!moderation plugin")
      end
    end

    context "when the help command has extra arguments" do
      let(:content) { "!moderation help add" }

      it "responds with usage" do
        command.handle(event)

        expect(event).to have_received(:respond).with(described_class::USAGE)
      end
    end

    context "when listing watched users" do
      let(:content) { "!moderation watchlist" }

      it "responds with user mentions" do
        command.handle(event)

        expect(event).to have_received(:respond).with("Watch list: <@456>, <@789>")
      end
    end

    context "when listing an empty watch list" do
      let(:content) { "!moderation watchlist" }

      before do
        allow(store).to receive(:get_watch_list_users).and_return([])
      end

      it "responds with an empty message" do
        command.handle(event)

        expect(event).to have_received(:respond).with("Watch list: empty")
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

    context "when a plugin command matches" do
      let(:content) { "!moderation plugin" }

      before do
        allow(plugin_command).to receive(:matches?).with(event).and_return(true)
      end

      it "dispatches to the plugin command" do
        command.handle(event)

        expect(plugin_command).to have_received(:handle).with(event)
        expect(event).not_to have_received(:respond).with(described_class::USAGE)
      end
    end

    context "when a built-in command matches before a plugin command" do
      let(:content) { "!moderation help" }

      before do
        allow(plugin_command).to receive(:matches?).with(event).and_return(true)
      end

      it "keeps the built-in command behavior" do
        command.handle(event)

        expect(plugin_command).not_to have_received(:handle)
        expect(event).to have_received(:respond).with("#{described_class::HELP_TEXT}\n!moderation plugin")
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

        expect(store).to have_received(:set_user_karma).with(123, 456, 0, actor_id: 42)
        expect(event).to have_received(:respond).with("Reset karma for <@456>")
      end
    end

    context "when setting user karma" do
      let(:content) { "!moderation karma set <@456> -7" }

      it "sets the user's karma score" do
        command.handle(event)

        expect(store).to have_received(:set_user_karma).with(123, 456, -7, actor_id: 42)
        expect(event).to have_received(:respond).with("Karma for <@456> set to -7")
      end
    end

    context "when setting user karma to zero" do
      let(:content) { "!moderation karma set <@456> 0" }

      before do
        allow(store).to receive(:set_user_karma).and_return(0)
      end

      it "sets the user's karma score" do
        command.handle(event)

        expect(store).to have_received(:set_user_karma).with(123, 456, 0, actor_id: 42)
        expect(event).to have_received(:respond).with("Karma for <@456> set to 0")
      end
    end

    context "when setting user karma without a score" do
      let(:content) { "!moderation karma set <@456>" }

      it "responds with usage" do
        command.handle(event)

        expect(event).to have_received(:respond).with(described_class::USAGE)
      end
    end

    context "when adding user karma" do
      let(:content) { "!moderation karma add <@456> 2" }

      it "increases the user's karma score" do
        command.handle(event)

        expect(store).to have_received(:increment_user_karma).with(123, 456, 2, actor_id: 42)
        expect(event).to have_received(:respond).with("Karma for <@456>: -2")
      end
    end

    context "when removing user karma" do
      let(:content) { "!moderation karma remove <@456> 2" }

      it "decreases the user's karma score" do
        command.handle(event)

        expect(store).to have_received(:decrement_user_karma).with(123, 456, 2, actor_id: 42)
        expect(event).to have_received(:respond).with("Karma for <@456>: -2")
      end
    end

    context "when checking karma history" do
      let(:content) { "!moderation karma history <@456>" }

      it "responds with recent karma events" do
        command.handle(event)

        expect(store).to have_received(:get_user_karma_history).with(123, 456, 5)
        expect(event).to have_received(:respond).with(
          "Karma history for <@456>:\n" \
          "- -1 => -3 via automated_infraction at 2026-04-19T12:00:00Z\n" \
          "- +2 => -2 via manual_adjustment by <@42> at 2026-04-19T12:05:00Z",
        )
      end
    end

    context "when checking karma history with a limit" do
      let(:content) { "!moderation karma history <@456> 1" }

      it "passes the requested history limit" do
        command.handle(event)

        expect(store).to have_received(:get_user_karma_history).with(123, 456, 1)
      end
    end

    context "when checking karma history with a large limit" do
      let(:content) { "!moderation karma history <@456> 99" }

      it "caps the requested history limit" do
        command.handle(event)

        expect(store).to have_received(:get_user_karma_history).with(123, 456, 10)
      end
    end

    context "when karma history is empty" do
      let(:content) { "!moderation karma history <@456>" }

      before do
        allow(store).to receive(:get_user_karma_history).and_return([])
      end

      it "responds with an empty-history message" do
        command.handle(event)

        expect(event).to have_received(:respond).with("No karma history for <@456>")
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
