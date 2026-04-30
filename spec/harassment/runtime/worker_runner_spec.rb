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
    thread = instance_double("Thread")
    allow(thread).to receive(:kill).and_return(thread)
    allow(thread).to receive(:join)
    allow(Thread).to receive(:new).and_return(thread)
    runner = described_class.new(runtime: runtime)

    runner.start
    runner.stop

    expect(thread).to have_received(:kill)
    expect(thread).to have_received(:join).with(1)
    expect(runner.running?).to be(false)
  end

  it "logs a failed processing pass without stopping the worker loop" do
    runtime = instance_double("Runtime")
    allow(runtime).to receive(:process_due_classifications).and_raise(StandardError, "boom")
    runner = described_class.new(runtime: runtime)
    allow(Logging.logger).to receive(:error)

    runner.send(:process_once)

    expect(Logging.logger).to have_received(:error).with(
      event: "harassment_worker_failed",
      error_class: "StandardError",
      error_message: "boom"
    )
  end
end
