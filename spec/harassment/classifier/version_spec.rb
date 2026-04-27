require "harassment/classifier/version"

describe Harassment::ClassifierVersion do
  it "builds a normalized classifier version" do
    version = described_class.build(" harassment-v1 ")

    expect(version.value).to eq("harassment-v1")
    expect(version.to_s).to eq("harassment-v1")
  end

  it "rejects empty classifier versions" do
    expect { described_class.build("   ") }.to raise_error(ArgumentError, "classifier version must not be empty")
  end
end
