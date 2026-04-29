require "plugins/admin_notifications_plugin"
require "ai/moderation_result"

describe OpenModBot::Plugins::AdminNotificationsPlugin do
  around do |example|
    original = ENV.to_h
    example.run
  ensure
    ENV.replace(original)
  end

  let(:event) { moderation_event(content: "maybe bad", server_id: 123, channel_id: 456, user_id: 789) }
  let(:channel) { instance_double("AdminChannel", send_message: true) }
  let(:bot) { instance_double("DiscordBot", channel: channel) }
  let(:result) do
    OpenModBot::AI::ModerationResult.new(
      flagged: false,
      categories: { harassment: false },
      category_scores: { harassment: 0.52, violence: 0.1 }
    )
  end

  before do
    ENV["ADMIN_NOTIFICATION_CHANNEL_ID"] = "999"
  end

  it "requires a notification channel when enabled" do
    ENV.delete("ADMIN_NOTIFICATION_CHANNEL_ID")

    expect { described_class.new.boot }.to raise_error(
      RuntimeError,
      "ADMIN_NOTIFICATION_CHANNEL_ID is required when admin_notifications plugin is enabled"
    )
  end

  it "notifies the configured channel for ambiguous moderation scores" do
    plugin = described_class.new
    plugin.boot
    plugin.message(event:, app: :app, bot:)

    plugin.moderation_result(event:, result:, app: :app, strategy: "RemoveMessageStrategy")

    expect(bot).to have_received(:channel).with(999)
    expect(channel).to have_received(:send_message).with(
      include(
        "Moderation review needed",
        "server=123",
        "channel=<#456>",
        "message=111",
        "user=<@789>",
        "strategy=RemoveMessageStrategy",
        "ambiguous_scores=harassment=0.52"
      )
    )
  end

  it "does not notify for scores outside the ambiguous band" do
    plugin = described_class.new
    plugin.message(event:, app: :app, bot:)
    clear_result = OpenModBot::AI::ModerationResult.new(
      flagged: false,
      categories: {},
      category_scores: { harassment: 0.91 }
    )

    plugin.moderation_result(event:, result: clear_result, app: :app, strategy: "RemoveMessageStrategy")

    expect(channel).not_to have_received(:send_message)
  end

  it "deduplicates moderation notifications for the same message" do
    plugin = described_class.new
    plugin.message(event:, app: :app, bot:)

    2.times { plugin.moderation_result(event:, result:, app: :app, strategy: "RemoveMessageStrategy") }

    expect(channel).to have_received(:send_message).once
  end

  it "honors the per-server rate limit" do
    now = Time.utc(2026, 4, 29, 12, 0, 0)
    ENV["ADMIN_NOTIFICATION_RATE_LIMIT_PER_MINUTE"] = "1"
    plugin = described_class.new(clock: -> { now })
    second_event = moderation_event(content: "maybe bad too", server_id: 123, channel_id: 456, user_id: 790)
    plugin.message(event:, app: :app, bot:)

    plugin.moderation_result(event:, result:, app: :app, strategy: "RemoveMessageStrategy")
    plugin.moderation_result(event: second_event, result:, app: :app, strategy: "RemoveMessageStrategy")

    expect(channel).to have_received(:send_message).once
  end

  it "can suppress ambiguous notifications while moderation shadow mode is enabled" do
    ENV["MODERATION_SHADOW_MODE"] = "true"
    ENV["ADMIN_NOTIFICATION_SHADOW_MODE"] = "false"
    plugin = described_class.new
    plugin.message(event:, app: :app, bot:)

    plugin.moderation_result(event:, result:, app: :app, strategy: "RemoveMessageStrategy")

    expect(channel).not_to have_received(:send_message)
  end

  it "notifies for automod outcomes" do
    plugin = described_class.new
    plugin.message(event:, app: :app, bot:)

    plugin.automod_outcome(
      event: event,
      score: -5,
      outcome: "automod_timeout_applied",
      app: :app,
      strategy: "RemoveMessageStrategy"
    )

    expect(channel).to have_received(:send_message).with(
      include("Automod outcome recorded", "score=-5", "outcome=automod_timeout_applied")
    )
  end
end
