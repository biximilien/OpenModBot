require "moderation/review_action"
require "moderation/strategies/watch_list_strategy"
require "moderation/automod_outcome"
require "open_ai"

describe WatchListStrategy do
  around do |example|
    original = ENV.to_h
    example.run
  ensure
    ENV.replace(original)
  end

  let(:server) { instance_double("Server", id: 123) }
  let(:channel) { instance_double("Channel", id: 789) }
  let(:message) { instance_double("Message", id: 111, content: "bad message", delete: true) }
  let(:user) { instance_double("User", id: 456) }
  let(:event) { instance_double("Event", server: server, channel: channel, message: message, user: user, respond: true) }
  let(:bot) { instance_double("Bot") }
  let(:automod_policy) { instance_double("AutomodPolicy", apply: Moderation::AutomodOutcome::TIMEOUT_APPLIED) }
  let(:plugin_registry) do
    instance_double(
      "PluginRegistry",
      moderation_result: true,
      infraction: true,
      automod_outcome: true,
      rewrite_instructions: nil,
    )
  end

  before do
    allow(bot).to receive(:get_user_karma).with(123, 456).and_return(0)
    allow(bot).to receive(:record_user_karma_event)
  end

  it "ignores users outside the watch list" do
    allow(bot).to receive(:get_watch_list_users).with(123).and_return([])

    expect(described_class.new(bot).condition(event)).to be(false)
  end

  it "matches flagged messages from watched users" do
    result = OpenAI::ModerationResult.new(flagged: true, categories: {}, category_scores: {})
    allow(bot).to receive(:get_watch_list_users).with(123).and_return([456])
    allow(bot).to receive(:moderate_text).with("bad message", user).and_return(result)

    expect(described_class.new(bot, plugin_registry: plugin_registry).condition(event)).to be(true)
    expect(plugin_registry).to have_received(:moderation_result).with(
      event: event,
      result: result,
      app: bot,
      strategy: "WatchListStrategy",
    )
  end

  it "rewrites and replaces matched messages" do
    allow(bot).to receive(:moderation_rewrite).with("bad message", user).and_return("Please be kinder.")
    allow(bot).to receive(:decrement_user_karma).with(123, 456).and_return(-1)

    described_class.new(bot, automod_policy: automod_policy).execute(event)

    expect(message).to have_received(:delete).with("Moderation (rewriting due to negative sentiment)")
    expect(bot).to have_received(:decrement_user_karma).with(123, 456)
    expect(event).to have_received(:respond).with("A message from <@456> was rewritten:\nPlease be kinder.")
  end

  it "uses plugin rewrite instructions when available" do
    allow(plugin_registry).to receive(:rewrite_instructions).and_return("Use pirate voice.")
    allow(bot).to receive(:moderation_rewrite).with("bad message", user, instructions: "Use pirate voice.").and_return("Avast, be kinder.")
    allow(bot).to receive(:decrement_user_karma).with(123, 456).and_return(-1)

    described_class.new(bot, automod_policy: automod_policy, plugin_registry: plugin_registry).execute(event)

    expect(plugin_registry).to have_received(:rewrite_instructions).with(
      event: event,
      app: bot,
      strategy: "WatchListStrategy",
    )
    expect(event).to have_received(:respond).with("A message from <@456> was rewritten:\nAvast, be kinder.")
  end

  it "does not repost original content when the rewrite is empty" do
    allow(bot).to receive(:moderation_rewrite).with("bad message", user).and_return(" ")
    allow(bot).to receive(:decrement_user_karma).with(123, 456).and_return(-1)

    described_class.new(bot, automod_policy: automod_policy).execute(event)

    expect(message).to have_received(:delete).with("Moderation (rewriting due to negative sentiment)")
    expect(event).to have_received(:respond).with("A message from <@456> was removed.")
  end

  it "records would-rewrite reviews without deleting, reposting, or changing karma in shadow mode" do
    ENV["MODERATION_SHADOW_MODE"] = "true"
    result = OpenAI::ModerationResult.new(flagged: true, categories: {}, category_scores: {})
    allow(bot).to receive(:get_watch_list_users).with(123).and_return([456])
    allow(bot).to receive(:moderate_text).with("bad message", user).and_return(result)
    allow(bot).to receive(:moderation_rewrite).with("bad message", user).and_return("Please be kinder.")
    allow(bot).to receive(:decrement_user_karma)
    allow(bot).to receive(:record_moderation_review)
    strategy = described_class.new(bot, automod_policy: automod_policy, plugin_registry: plugin_registry)

    strategy.condition(event)
    strategy.execute(event)

    expect(message).not_to have_received(:delete)
    expect(event).not_to have_received(:respond)
    expect(bot).not_to have_received(:decrement_user_karma)
    expect(bot).to have_received(:record_moderation_review).with(hash_including(action: Moderation::ReviewAction::WOULD_REWRITE, rewrite: "Please be kinder.", shadow_mode: true))
  end

  it "can skip rewrite generation in shadow mode" do
    ENV["MODERATION_SHADOW_MODE"] = "true"
    ENV["MODERATION_SHADOW_REWRITE"] = "false"
    result = OpenAI::ModerationResult.new(flagged: true, categories: {}, category_scores: {})
    allow(bot).to receive(:get_watch_list_users).with(123).and_return([456])
    allow(bot).to receive(:moderate_text).with("bad message", user).and_return(result)
    allow(bot).to receive(:moderation_rewrite)
    allow(bot).to receive(:record_moderation_review)
    strategy = described_class.new(bot, automod_policy: automod_policy, plugin_registry: plugin_registry)

    strategy.condition(event)
    strategy.execute(event)

    expect(bot).not_to have_received(:moderation_rewrite)
    expect(bot).to have_received(:record_moderation_review).with(hash_including(action: Moderation::ReviewAction::WOULD_REWRITE, rewrite: nil, shadow_mode: true))
  end
end
