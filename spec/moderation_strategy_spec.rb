require "moderation_strategy"
require "moderation/automod_outcome"
require "open_ai"

describe RemoveMessageStrategy do
  let(:server) { instance_double("Server", id: 123) }
  let(:message) { instance_double("Message", content: "bad message", delete: true) }
  let(:user) { instance_double("User", id: 456) }
  let(:event) { instance_double("Event", server: server, message: message, user: user) }
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

  it "matches flagged messages" do
    result = OpenAI::ModerationResult.new(flagged: true, categories: {}, category_scores: {})
    allow(bot).to receive(:moderate_text).with("bad message", user).and_return(result)

    expect(described_class.new(bot, plugin_registry: plugin_registry).condition(event)).to eq(true)
    expect(plugin_registry).to have_received(:moderation_result).with(
      event: event,
      result: result,
      app: bot,
      strategy: "RemoveMessageStrategy",
    )
  end

  it "deletes matched messages" do
    allow(bot).to receive(:decrement_user_karma).with(123, 456).and_return(-1)

    described_class.new(bot, automod_policy: automod_policy, plugin_registry: plugin_registry).execute(event)

    expect(message).to have_received(:delete).with("Moderation (removing message)")
    expect(bot).to have_received(:decrement_user_karma).with(123, 456)
    expect(plugin_registry).to have_received(:infraction).with(
      event: event,
      score: -1,
      app: bot,
      strategy: "RemoveMessageStrategy",
    )
  end

  it "applies automated moderation policy when the user reaches the threshold" do
    allow(bot).to receive(:get_user_karma).with(123, 456).and_return(-4)
    allow(bot).to receive(:decrement_user_karma).with(123, 456).and_return(-5)

    described_class.new(bot, automod_policy: automod_policy, plugin_registry: plugin_registry).execute(event)

    expect(automod_policy).to have_received(:apply).with(event, -5)
  end

  it "records automated moderation outcomes in karma history" do
    allow(bot).to receive(:get_user_karma).with(123, 456).and_return(-4)
    allow(bot).to receive(:decrement_user_karma).with(123, 456).and_return(-5)

    described_class.new(bot, automod_policy: automod_policy, plugin_registry: plugin_registry).execute(event)

    expect(bot).to have_received(:record_user_karma_event).with(
      123,
      456,
      score: -5,
      source: Moderation::AutomodOutcome::TIMEOUT_APPLIED,
    )
    expect(plugin_registry).to have_received(:automod_outcome).with(
      event: event,
      score: -5,
      outcome: Moderation::AutomodOutcome::TIMEOUT_APPLIED,
      app: bot,
      strategy: "RemoveMessageStrategy",
    )
  end

  it "does not reapply automated moderation while the user is already below the threshold" do
    allow(bot).to receive(:get_user_karma).with(123, 456).and_return(-5)
    allow(bot).to receive(:decrement_user_karma).with(123, 456).and_return(-6)

    described_class.new(bot, automod_policy: automod_policy).execute(event)

    expect(automod_policy).not_to have_received(:apply)
    expect(bot).not_to have_received(:record_user_karma_event)
  end
end

describe WatchListStrategy do
  let(:server) { instance_double("Server", id: 123) }
  let(:message) { instance_double("Message", content: "bad message", delete: true) }
  let(:user) { instance_double("User", id: 456) }
  let(:event) { instance_double("Event", server: server, message: message, user: user, respond: true) }
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

    expect(described_class.new(bot).condition(event)).to eq(false)
  end

  it "matches flagged messages from watched users" do
    result = OpenAI::ModerationResult.new(flagged: true, categories: {}, category_scores: {})
    allow(bot).to receive(:get_watch_list_users).with(123).and_return([456])
    allow(bot).to receive(:moderate_text).with("bad message", user).and_return(result)

    expect(described_class.new(bot, plugin_registry: plugin_registry).condition(event)).to eq(true)
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
end

describe "moderation strategy result caching" do
  let(:server) { instance_double("Server", id: 123) }
  let(:message) { instance_double("Message", content: "fine message") }
  let(:user) { instance_double("User", id: 456) }
  let(:event) { instance_double("Event", server: server, message: message, user: user) }
  let(:bot) { instance_double("Bot") }
  let(:plugin_registry) do
    instance_double(
      "PluginRegistry",
      moderation_result: true,
      infraction: true,
      automod_outcome: true,
      rewrite_instructions: nil,
    )
  end

  it "reuses a watchlist moderation result when fallback strategy checks the same event" do
    result = OpenAI::ModerationResult.new(flagged: false, categories: {}, category_scores: {})
    allow(bot).to receive(:get_watch_list_users).with(123).and_return([456])
    allow(bot).to receive(:moderate_text).with("fine message", user).and_return(result)

    watchlist = WatchListStrategy.new(bot, plugin_registry: plugin_registry)
    fallback = RemoveMessageStrategy.new(bot, plugin_registry: plugin_registry)

    expect(watchlist.condition(event)).to eq(false)
    expect(fallback.condition(event)).to eq(false)
    expect(bot).to have_received(:moderate_text).once
    expect(plugin_registry).to have_received(:moderation_result).once
  end
end
