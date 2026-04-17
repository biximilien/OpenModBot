module Moderation
  class MessageRouter
    def initialize(strategies)
      @strategies = strategies
    end

    def handle(event)
      @strategies.any? do |strategy|
        execute_strategy?(strategy, event)
      end
    end

    private

    def execute_strategy?(strategy, event)
      return false unless strategy.condition(event)

      strategy.execute(event)
      true
    rescue StandardError => e
      $logger.error("Moderation strategy failed: #{e.class}: #{e.message}")
      false
    end
  end
end
