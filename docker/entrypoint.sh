#!/bin/sh
set -e

if echo ",${PLUGINS}," | grep -q ",postgres,"; then
  ruby -ruri -rsocket -e '
    uri = URI(ENV.fetch("DATABASE_URL"))
    host = uri.host
    port = uri.port || 5432
    deadline = Time.now + 60

    loop do
      begin
        socket = TCPSocket.new(host, port)
        socket.close
        break
      rescue StandardError
        raise "Timed out waiting for Postgres at #{host}:#{port}" if Time.now >= deadline
        sleep 1
      end
    end
  '
fi

exec bundle exec ruby bot.rb
