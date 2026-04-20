require "telemetry"

describe Telemetry do
  around do |example|
    original = ENV.to_h
    original_tracer = described_class.instance_variable_get(:@tracer)
    example.run
  ensure
    ENV.replace(original)
    described_class.instance_variable_set(:@tracer, original_tracer)
  end

  describe ".configure!" do
    it "leaves telemetry disabled by default" do
      ENV.delete("TELEMETRY_ENABLED")

      expect(described_class.configure!).to eq(false)
      expect(described_class.enabled?).to eq(false)
    end
  end

  describe ".in_span" do
    it "yields a no-op span when telemetry is disabled" do
      described_class.instance_variable_set(:@tracer, Telemetry::NoopTracer.new)

      yielded = nil
      described_class.in_span("test") do |span|
        yielded = span
        span.add_event("event")
        span.set_attribute("key", "value")
      end

      expect(yielded).to be_a(Telemetry::NoopSpan)
    end
  end
end
