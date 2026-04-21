require "moderation/automod_outcome"

describe Moderation::AutomodOutcome do
  it "defines persisted automod outcome source values" do
    expect(described_class::LOG_ONLY).to eq("automod_log_only")
    expect(described_class::TIMEOUT_APPLIED).to eq("automod_timeout_applied")
    expect(described_class::TIMEOUT_UNAVAILABLE).to eq("automod_timeout_unavailable")
    expect(described_class::KICK_APPLIED).to eq("automod_kick_applied")
    expect(described_class::KICK_UNAVAILABLE).to eq("automod_kick_unavailable")
    expect(described_class::BAN_APPLIED).to eq("automod_ban_applied")
    expect(described_class::BAN_UNAVAILABLE).to eq("automod_ban_unavailable")
    expect(described_class::SKIPPED_ELEVATED_MEMBER).to eq("automod_skipped_elevated_member")
  end
end
