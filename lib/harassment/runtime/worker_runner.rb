require_relative "../../logging"

module Harassment
  class WorkerRunner
    DEFAULT_INTERVAL_SECONDS = 5

    def initialize(runtime:, interval_seconds: DEFAULT_INTERVAL_SECONDS)
      @runtime = runtime
      @interval_seconds = interval_seconds
      @thread = nil
    end

    def start
      return @thread if @thread

      @thread = Thread.new do
        Thread.current.name = "harassment-worker" if Thread.current.respond_to?(:name=)

        loop do
          process_once
          sleep @interval_seconds
        end
      ensure
        @thread = nil
      end
    end

    def stop
      @thread&.kill
      @thread = nil
    end

    def running?
      !@thread.nil?
    end

    private

    def process_once
      @runtime.process_due_classifications
    rescue StandardError => e
      Logging.error("harassment_worker_failed", error_class: e.class.name, error_message: e.message)
      nil
    end
  end
end
