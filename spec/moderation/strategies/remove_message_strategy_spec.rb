require "moderation/automod_outcome"
require "moderation/review_action"
require "moderation/strategies/remove_message_strategy"
require "open_ai"

describe RemoveMessageStrategy do
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
  let(:event) { instance_double("Event", server: server, channel: channel, message: message, user: user) }
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

    expect(described_class.new(bot, plugin_registry: plugin_registry).condition(event)).to be(true)
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

  it "records live moderation reviews when review storage is available" do
    result = OpenAI::ModerationResult.new(flagged: true, categories: { "harassment" => true }, category_scores: { "harassment" => 0.9 })
    allow(bot).to receive(:moderate_text).with("bad message", user).and_return(result)
    allow(bot).to receive(:decrement_user_karma).with(123, 456).and_return(-1)
    allow(bot).to receive(:record_moderation_review)
    strategy = described_class.new(bot, automod_policy: automod_policy, plugin_registry: plugin_registry)

    strategy.condition(event)
    strategy.execute(event)

    expect(bot).to have_received(:record_moderation_review).with(
      hash_including(
        server_id: 123,
        channel_id: 789,
        message_id: 111,
        user_id: 456,
        strategy: "RemoveMessageStrategy",
        action: Moderation::ReviewAction::REMOVED,
        shadow_mode: false,
        flagged: true,
        categories: { "harassment" => true },
      ),
    )
  end

  it "records would-remove reviews without deleting or changing karma in shadow mode" do
    ENV["MODERATION_SHADOW_MODE"] = "true"
    result = OpenAI::ModerationResult.new(flagged: true, categories: {}, category_scores: {})
    allow(bot).to receive(:moderate_text).with("bad message", user).and_return(result)
    allow(bot).to receive(:decrement_user_karma)
    allow(bot).to receive(:record_moderation_review)
    strategy = described_class.new(bot, automod_policy: automod_policy, plugin_registry: plugin_registry)

    strategy.condition(event)
    strategy.execute(event)

    expect(message).not_to have_received(:delete)
    expect(bot).not_to have_received(:decrement_user_karma)
    expect(bot).to have_received(:record_moderation_review).with(hash_including(action: Moderation::ReviewAction::WOULD_REMOVE, shadow_mode: true))
  end

  it "stores original content in review entries only when explicitly enabled" do
    ENV["MODERATION_REVIEW_STORE_CONTENT"] = "true"
    result = OpenAI::ModerationResult.new(flagged: true, categories: {}, category_scores: {})
    allow(bot).to receive(:moderate_text).with("bad message", user).and_return(result)
    allow(bot).to receive(:decrement_user_karma).with(123, 456).and_return(-1)
    allow(bot).to receive(:record_moderation_review)
    strategy = described_class.new(bot, automod_policy: automod_policy, plugin_registry: plugin_registry)

    strategy.condition(event)
    strategy.execute(event)

    expect(bot).to have_received(:record_moderation_review).with(hash_including(original_content: "bad message"))
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
