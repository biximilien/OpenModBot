require "moderation/automod_policy"

describe Moderation::AutomodPolicy do
  let(:user) { instance_double("User", id: 456) }
  let(:server) { instance_double("Server") }
  let(:event) { instance_double("Event", user: user, server: server) }

  it "logs threshold crossings for log_only policy" do
    policy = described_class.new(action: "log_only")
    allow($logger).to receive(:warn)

    policy.apply(event, -5)

    expect($logger).to have_received(:warn).with(
      "User #{Telemetry::Anonymizer.hash(456)} reached automated moderation threshold with karma -5",
    )
  end

  it "times out users for timeout policy" do
    member = instance_double("Member", timeout_for: true)
    allow(event).to receive(:member).and_return(member)

    described_class.new(action: "timeout", timeout_seconds: 120).apply(event, -5)

    expect(member).to have_received(:timeout_for).with(120, "Automated moderation: karma -5")
  end

  it "uses Discord API fallback for timeout when no member timeout helper exists" do
    bot = instance_double("Bot", token: "discord-token")
    server = instance_double("Server", id: 123)
    server.instance_variable_set(:@bot, bot)
    event = instance_double("Event", user: user, server: server)
    allow(Discordrb::API).to receive(:request)

    described_class.new(action: "timeout", timeout_seconds: 120).apply(event, -5)

    expect(Discordrb::API).to have_received(:request).with(
      :guilds_sid_members_uid,
      123,
      :patch,
      "#{Discordrb::API.api_base}/guilds/123/members/456",
      kind_of(String),
      Authorization: "discord-token",
      content_type: :json,
      "X-Audit-Log-Reason": "Automated moderation: karma -5",
    )
  end

  it "falls back to timeout when an invalid policy is configured" do
    member = instance_double("Member", timeout_for: true)
    allow(event).to receive(:member).and_return(member)

    described_class.new(action: "nonsense", timeout_seconds: 120).apply(event, -5)

    expect(member).to have_received(:timeout_for).with(120, "Automated moderation: karma -5")
  end

  it "kicks users for kick policy" do
    allow(server).to receive(:kick)

    described_class.new(action: "kick").apply(event, -5)

    expect(server).to have_received(:kick).with(user, "Automated moderation: karma -5")
  end

  it "bans users for ban policy" do
    allow(server).to receive(:ban)

    described_class.new(action: "ban").apply(event, -5)

    expect(server).to have_received(:ban).with(user, 0, reason: "Automated moderation: karma -5")
  end
end
