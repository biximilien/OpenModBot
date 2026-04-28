require "discord/watchlist_command"

describe Discord::WatchlistCommand do
  subject(:command) { described_class.new(store: store, usage: "usage") }

  let(:store) do
    instance_double(
      "Store",
      get_watch_list_users: [456],
      add_user_to_watch_list: true,
      remove_user_from_watch_list: true,
    )
  end
  let(:server) { instance_double("Server", id: 123) }
  let(:event) { instance_double("Event", server: server, respond: true) }


  it "lists watched users" do
    command.handle(event, match(nil))

    expect(event).to have_received(:respond).with("Watch list: <@456>")
  end

  it "adds watched users" do
    command.handle(event, match("add", user_id: "789"))

    expect(store).to have_received(:add_user_to_watch_list).with(123, 789)
    expect(event).to have_received(:respond).with("Added <@789> to watch list")
  end

  def match(subcommand, user_id: nil)
    { subcommand:, user_id: }
  end
end
