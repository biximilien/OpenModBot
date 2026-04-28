require "telemetry/anonymizer"

describe Telemetry::Anonymizer do
  around do |example|
    original = ENV.to_h
    example.run
  ensure
    ENV.replace(original)
  end

  it "returns a stable salted hash" do
    ENV["TELEMETRY_HASH_SALT"] = "salt-a"
    first = described_class.hash(123)

    expect(described_class.hash(123)).to eq(first)
  end

  it "changes hashes when the salt changes" do
    ENV["TELEMETRY_HASH_SALT"] = "salt-a"
    first = described_class.hash(123)

    ENV["TELEMETRY_HASH_SALT"] = "salt-b"

    expect(described_class.hash(123)).not_to eq(first)
  end

  it "does not include the original value" do
    ENV["TELEMETRY_HASH_SALT"] = "salt-a"

    expect(described_class.hash(123)).not_to include("123")
  end
end
