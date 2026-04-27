require "harassment/runtime/worker_runner"

describe Harassment::WorkerRunner do
  it "starts the worker loop only once" do
    runtime = instance_double("Runtime", process_due_classifications: true)
    runner = described_class.new(runtime: runtime, interval_seconds: 60)
    thread = instance_double("Thread")
    allow(Thread).to receive(:new).and_return(thread)

    expect(runner.start).to eq(thread)
    expect(runner.start).to eq(thread)
    expect(Thread).to have_received(:new).once
  end

  it "stops a running worker" do
    runtime = instance_double("Runtime")
    thread = instance_double("Thread", kill: true)
    allow(Thread).to receive(:new).and_return(thread)
    runner = described_class.new(runtime: runtime)

    runner.start
    runner.stop

    expect(thread).to have_received(:kill)
    expect(runner.running?).to eq(false)
  end
end
