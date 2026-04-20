require "plugins/telemetry_plugin"

describe ModerationGPT::Plugins::TelemetryPlugin do
  it "configures telemetry on boot" do
    allow(Telemetry).to receive(:configure!).and_return(false)

    described_class.new.boot

    expect(Telemetry).to have_received(:configure!)
  end
end
