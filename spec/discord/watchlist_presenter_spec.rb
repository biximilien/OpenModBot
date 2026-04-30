require "discord/watchlist_presenter"

describe Discord::WatchlistPresenter do
  subject(:presenter) { described_class.new }

  it "formats watchlist responses" do
    expect(presenter.list([456, 789])).to eq("Watch list: <@456>, <@789>")
    expect(presenter.list([])).to eq("Watch list: empty")
    expect(presenter.added("456")).to eq("Added <@456> to watch list")
    expect(presenter.removed("456")).to eq("Removed <@456> from watch list")
  end
end
