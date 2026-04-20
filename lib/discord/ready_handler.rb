require_relative "../telemetry/anonymizer"

module Discord
  class ReadyHandler
    TEXT_CHANNEL = 0

    def initialize(bot, store)
      @bot = bot
      @store = store
    end

    def handle(_event)
      $logger.info("Ready!")
      @bot.online

      $logger.info("Servers: #{@bot.servers.size}")

      @bot.servers.each do |server_id, server|
        $logger.info("Server connected: server=#{Telemetry::Anonymizer.hash(server_id)} channels=#{server.channels.size}")
        @store.add_server(server_id)
        log_text_channels(server)
      end
    end

    private

    def log_text_channels(server)
      server.channels.each do |channel|
        next unless channel.type == TEXT_CHANNEL

        $logger.info("Text channel discovered: channel=#{Telemetry::Anonymizer.hash(channel.id)}")
      end
    end
  end
end
