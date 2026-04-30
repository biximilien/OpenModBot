require "discord/karma_presenter"

describe Discord::KarmaPresenter do
  subject(:presenter) { described_class.new }

  it "formats score and mutation responses" do
    expect(presenter.score("456", -2)).to eq("Karma for <@456>: -2")
    expect(presenter.set("456", 0)).to eq("Karma for <@456> set to 0")
    expect(presenter.reset("456")).to eq("Reset karma for <@456>")
  end

  it "formats karma history" do
    expect(
      presenter.history(
        456,
        [
          { created_at: "2026-04-19T12:00:00Z", delta: -1, score: -3, source: "automated_infraction" },
          { created_at: "2026-04-19T12:05:00Z", delta: 2, score: -2, source: "manual_adjustment", actor_id: 42 }
        ]
      )
    ).to eq(
      "Karma history for <@456>:\n" \
      "- -1 => -3 via automated_infraction at 2026-04-19T12:00:00Z\n" \
      "- +2 => -2 via manual_adjustment by <@42> at 2026-04-19T12:05:00Z"
    )
  end

  it "formats empty karma history" do
    expect(presenter.history(456, [])).to eq("No karma history for <@456>")
  end
end
