require "harassment/runtime/server_rate_limiter"
require "harassment/repositories/in_memory_server_rate_limit_repository"

describe Harassment::ServerRateLimiter do
  subject(:limiter) do
    described_class.new(
      repository: repository,
      limit_per_minute: 2
    )
  end

  let(:repository) { Harassment::Repositories::InMemoryServerRateLimitRepository.new }

  it "allows requests under the per-server limit and returns a retry time once exceeded" do
    now = Time.utc(2026, 4, 25, 18, 0, 0)

    expect(limiter.reserve("456", at: now)).to be_nil
    expect(limiter.reserve("456", at: now + 5)).to be_nil
    expect(limiter.reserve("456", at: now + 10)).to eq(now + 60)
  end

  it "tracks limits independently per server" do
    now = Time.utc(2026, 4, 25, 18, 0, 0)

    limiter.reserve("456", at: now)
    limiter.reserve("456", at: now + 1)

    expect(limiter.reserve("789", at: now + 2)).to be_nil
  end
end
