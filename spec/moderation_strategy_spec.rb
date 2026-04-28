require "moderation/strategy"
require "moderation/strategies/remove_message_strategy"
require "moderation/strategies/watch_list_strategy"
require "open_ai"

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

    expect(watchlist.condition(event)).to be(false)
    expect(fallback.condition(event)).to be(false)
    expect(bot).to have_received(:moderate_text).once
    expect(plugin_registry).to have_received(:moderation_result).once
  end
end
