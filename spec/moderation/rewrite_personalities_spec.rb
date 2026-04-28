require "moderation/rewrite_personalities"

describe Moderation::RewritePersonalities do
  it "fetches known personality instructions" do
    expect(described_class.fetch("empathetic")).to include("calm, empathetic tone")
  end

  it "falls back to objective instructions for unknown personalities" do
    expect(described_class.fetch("unknown")).to eq(described_class.fetch(described_class::DEFAULT))
  end

  it "reports whether a personality is known" do
    expect(described_class).to be_known("objective")
    expect(described_class).not_to be_known("unknown")
  end
end
