require "moderation_strategy"
require "open_ai"

describe RemoveMessageStrategy do
  let(:message) { instance_double("Message", content: "bad message", delete: true) }
  let(:user) { instance_double("User") }
  let(:event) { instance_double("Event", message: message, user: user) }
  let(:bot) { instance_double("Bot") }

  it "matches flagged messages" do
    result = OpenAI::ModerationResult.new(flagged: true, categories: {}, category_scores: {})
    allow(bot).to receive(:moderate_text).with("bad message", user).and_return(result)

    expect(described_class.new(bot).condition(event)).to eq(true)
  end

  it "deletes matched messages" do
    described_class.new(bot).execute(event)

    expect(message).to have_received(:delete).with("Moderation (removing message)")
  end
end

describe WatchListStrategy do
  let(:server) { instance_double("Server", id: 123) }
  let(:message) { instance_double("Message", content: "bad message", delete: true) }
  let(:user) { instance_double("User", id: 456) }
  let(:event) { instance_double("Event", server: server, message: message, user: user, respond: true) }
  let(:bot) { instance_double("Bot") }

  it "ignores users outside the watch list" do
    allow(bot).to receive(:get_watch_list_users).with(123).and_return([])

    expect(described_class.new(bot).condition(event)).to eq(false)
  end

  it "matches flagged messages from watched users" do
    result = OpenAI::ModerationResult.new(flagged: true, categories: {}, category_scores: {})
    allow(bot).to receive(:get_watch_list_users).with(123).and_return([456])
    allow(bot).to receive(:moderate_text).with("bad message", user).and_return(result)

    expect(described_class.new(bot).condition(event)).to eq(true)
  end

  it "rewrites and replaces matched messages" do
    allow(bot).to receive(:moderation_rewrite).with("bad message", user).and_return("Please be kinder.")

    described_class.new(bot).execute(event)

    expect(message).to have_received(:delete).with("Moderation (rewriting due to negative sentiment)")
    expect(event).to have_received(:respond).with("~~<@456>: bad message~~\nPlease be kinder.")
  end
end
