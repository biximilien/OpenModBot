require "moderation/stores/in_memory_store"
require_relative "../../support/shared_examples/moderation_store_contract"

describe Moderation::Stores::InMemoryStore do
  subject(:store) { described_class.new }

  it_behaves_like "a moderation store"
end
