require "moderation/message_router"

describe Moderation::MessageRouter do
  let(:event) { instance_double("Event") }

  it "executes the first matching strategy" do
    first = instance_double("Strategy", condition: true, execute: true)
    second = instance_double("Strategy", condition: true, execute: true)

    result = described_class.new([first, second]).handle(event)

    expect(result).to eq(true)
    expect(first).to have_received(:execute).with(event)
    expect(second).not_to have_received(:condition)
  end

  it "skips strategies whose condition is false" do
    first = instance_double("Strategy", condition: false, execute: true)
    second = instance_double("Strategy", condition: true, execute: true)

    result = described_class.new([first, second]).handle(event)

    expect(result).to eq(true)
    expect(first).not_to have_received(:execute)
    expect(second).to have_received(:execute).with(event)
  end

  it "returns false when no strategy matches" do
    strategy = instance_double("Strategy", condition: false, execute: true)

    expect(described_class.new([strategy]).handle(event)).to eq(false)
    expect(strategy).not_to have_received(:execute)
  end

  it "continues after a strategy raises" do
    broken = instance_double("Strategy", condition: true)
    fallback = instance_double("Strategy", condition: true, execute: true)
    allow(broken).to receive(:execute).and_raise(StandardError, "boom")

    result = described_class.new([broken, fallback]).handle(event)

    expect(result).to eq(true)
    expect(fallback).to have_received(:execute).with(event)
  end
end
