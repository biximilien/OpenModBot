require_relative "../environment"
require_relative "telemetry/anonymizer"
require_relative "logging"

module Telemetry
  class NoopSpan
    def add_event(*); end

    def set_attribute(*); end
  end

  class NoopTracer
    def in_span(_name, attributes: {})
      _attributes = attributes
      yield NoopSpan.new
    end
  end

  module_function

  def configure!
    unless Environment.telemetry_enabled?
      @tracer = NoopTracer.new
      return false
    end

    require "opentelemetry-api"
    require "opentelemetry/sdk"
    require "opentelemetry/exporter/otlp"
    require "opentelemetry-instrumentation-net_http"
    require "opentelemetry/instrumentation/redis"

    OpenTelemetry::SDK.configure do |config|
      config.use "OpenTelemetry::Instrumentation::Net::HTTP"
      config.use "OpenTelemetry::Instrumentation::Redis"
    end

    @tracer = OpenTelemetry.tracer_provider.tracer("moderation_gpt", "1.0")
    true
  rescue LoadError => e
    Logging.warn("opentelemetry_disabled", error_class: e.class.name, error_message: e.message)
    @tracer = NoopTracer.new
    false
  end

  def in_span(name, attributes: {})
    tracer.in_span(name, attributes:) { |span| yield span }
  end

  def tracer
    @tracer ||= NoopTracer.new
  end

  def enabled?
    !tracer.is_a?(NoopTracer)
  end
end
