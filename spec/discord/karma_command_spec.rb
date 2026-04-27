require "discord/karma_command"

describe Discord::KarmaCommand do
  let(:store) do
    instance_double(
      "Store",
      get_user_karma: -3,
      increment_user_karma: -1,
      get_user_karma_history: [],
    )
  end
  let(:server) { instance_double("Server", id: 123) }
  let(:user) { instance_double("User", id: 42) }
  let(:event) { instance_double("Event", server: server, user: user, respond: true) }

  subject(:command) { described_class.new(store: store, usage: "usage") }

  it "reports user karma" do
    command.handle(event, match(nil, user_id: "456"))

    expect(store).to have_received(:get_user_karma).with(123, 456)
    expect(event).to have_received(:respond).with("Karma for <@456>: -3")
  end

  it "caps requested history limits" do
    command.handle(event, match("history", user_id: "456", amount: "99"))

    expect(store).to have_received(:get_user_karma_history).with(123, 456, 10)
  end

  def match(subcommand, user_id: nil, amount: nil)
    { subcommand:, user_id:, amount: }
  end
end
