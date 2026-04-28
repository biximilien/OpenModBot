require "discord/moderation_command_parser"

describe Discord::ModerationCommandParser do
  subject(:parser) { described_class.new }

  it "recognizes moderation triggers" do
    expect(parser.trigger?("!moderation watchlist")).to be(true)
    expect(parser.trigger?("hello there")).to be(false)
  end

  it "parses built-in command arguments" do
    match = parser.parse("!moderation karma add <@456> 2")

    expect(match[:command]).to eq("karma")
    expect(match[:subcommand]).to eq("add")
    expect(match[:user_id]).to eq("456")
    expect(match[:amount]).to eq("2")
  end

  it "parses moderation review commands" do
    match = parser.parse("!moderation review recent 3")

    expect(match[:command]).to eq("review")
    expect(match[:subcommand]).to eq("recent")
    expect(match[:amount]).to eq("3")
  end

  it "parses moderation review repost commands" do
    match = parser.parse("!moderation review repost 123456")

    expect(match[:command]).to eq("review")
    expect(match[:subcommand]).to eq("repost")
    expect(match[:amount]).to eq("123456")
  end

  it "keeps restore as a compatibility alias" do
    match = parser.parse("!moderation review restore 123456")

    expect(match[:subcommand]).to eq("restore")
  end

  it "rejects malformed token order" do
    expect(parser.parse("!moderation karma recent")).to be_nil
  end
end
