require "harassment/classifier/definition"

describe Harassment::ClassifierDefinition do
  subject(:definition) { described_class.new }

  it "owns classifier identity" do
    expect(definition.classifier_version).to eq("harassment-v1")
    expect(definition.prompt_version).to eq("harassment-prompt-v1")
  end

  it "builds the OpenAI classifier" do
    client = instance_double("OpenAIClient")

    classifier = definition.build(client:, model: "gpt-4o-test")

    expect(classifier).to be_a(Harassment::OpenAIClassifier)
  end
end
