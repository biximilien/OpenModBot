require_relative "../plugin"
require_relative "../telemetry"

module ModerationGPT
  module Plugins
    class TelemetryPlugin < Plugin
      def boot(**)
        Telemetry.configure!
      end
    end
  end
end
