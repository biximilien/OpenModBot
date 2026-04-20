require "moderation_strategy"
require "open_ai"

describe RemoveMessageStrategy do
  let(:server) { instance_double("Server", id: 123) }
  let(:message) { instance_double("Message", content: "bad message", delete: true) }
  let(:user) { instance_double("User", id: 456) }
  let(:event) { instance_double("Event", server: server, message: message, user: user) }
  let(:bot) { instance_double("Bot") }
  let(:automod_policy) { instance_double("AutomodPolicy", apply: true) }

  it "matches flagged messages" do
    result = OpenAI::ModerationResult.new(flagged: true, categories: {}, category_scores: {})
    allow(bot).to receive(:moderate_text).with("bad message", user).and_return(result)

    expect(described_class.new(bot).condition(event)).to eq(true)
  end

  it "deletes matched messages" do
    allow(bot).to receive(:decrement_user_karma).with(123, 456).and_return(-1)

    described_class.new(bot, automod_policy: automod_policy).execute(event)

    expect(message).to have_received(:delete).with("Moderation (removing message)")
    expect(bot).to have_received(:decrement_user_karma).with(123, 456)
  end

  it "applies automated moderation policy when the user reaches the threshold" do
    allow(bot).to receive(:decrement_user_karma).with(123, 456).and_return(-5)

    described_class.new(bot, automod_policy: automod_policy).execute(event)

    expect(automod_policy).to have_received(:apply).with(event, -5)
  end
end

describe WatchListStrategy do
  let(:server) { instance_double("Server", id: 123) }
  let(:message) { instance_double("Message", content: "bad message", delete: true) }
  let(:user) { instance_double("User", id: 456) }
  let(:event) { instance_double("Event", server: server, message: message, user: user, respond: true) }
  let(:bot) { instance_double("Bot") }
  let(:automod_policy) { instance_double("AutomodPolicy", apply: true) }

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
    allow(bot).to receive(:decrement_user_karma).with(123, 456).and_return(-1)

    described_class.new(bot, automod_policy: automod_policy).execute(event)

    expect(message).to have_received(:delete).with("Moderation (rewriting due to negative sentiment)")
    expect(bot).to have_received(:decrement_user_karma).with(123, 456)
    expect(event).to have_received(:respond).with("A message from <@456> was rewritten:\nPlease be kinder.")
  end

  it "does not repost original content when the rewrite is empty" do
    allow(bot).to receive(:moderation_rewrite).with("bad message", user).and_return(" ")
    allow(bot).to receive(:decrement_user_karma).with(123, 456).and_return(-1)

    described_class.new(bot, automod_policy: automod_policy).execute(event)

    expect(message).to have_received(:delete).with("Moderation (rewriting due to negative sentiment)")
    expect(event).to have_received(:respond).with("A message from <@456> was removed.")
  end
end
