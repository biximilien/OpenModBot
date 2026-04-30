module OpenModBot
  module Config
    module EnvReader
      private

      def env(name, default = nil)
        @env.fetch(name, default)
      end

      def true?(name, default:)
        env(name, default).casecmp("true").zero?
      end
    end
  end
end
