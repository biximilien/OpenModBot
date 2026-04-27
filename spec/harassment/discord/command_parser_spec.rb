require "harassment/discord/command_parser"

describe Harassment::Discord::CommandParser do
  subject(:parser) { described_class.new }

  it "parses risk commands" do
    match = parser.command_match("!moderation harassment risk <@456>")

    expect(match[:type]).to eq(:risk)
    expect(match[:data][:user_id]).to eq("456")
  end

  it "parses incidents filters in flexible order" do
    match = parser.command_match("!moderation harassment incidents <@456> 3 24h")

    expect(match).to eq(type: :incidents, data: { user_id: "456", window: "24h", limit: "3" })
  end

  it "rejects duplicate incidents filters" do
    expect(parser.command_match("!moderation harassment incidents 24h 7d")).to be_nil
  end
end
