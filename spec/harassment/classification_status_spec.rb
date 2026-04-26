require "harassment/classification_status"

describe Harassment::ClassificationStatus do
  it "defines the supported lifecycle states" do
    expect(described_class::ALL).to eq(%w[pending classified failed_retryable failed_terminal])
  end

  it "normalizes supported states and rejects unknown states" do
    expect(described_class.normalize!("classified")).to eq("classified")

    expect { described_class.normalize!("not-real", field_name: "classification_status") }
      .to raise_error(ArgumentError, "classification_status must be one of: pending, classified, failed_retryable, failed_terminal")
  end
end
