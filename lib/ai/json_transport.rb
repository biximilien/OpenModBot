require "json"
require "net/http"
require "uri"
require_relative "../telemetry"

module OpenModBot
  module AI
    class JsonTransport
      def initialize(provider_name:, headers:)
        @provider_name = provider_name
        @headers = headers
      end

      def post(url:, payload:, user: nil)
        Telemetry.in_span(url, attributes: telemetry_attributes(url, user)) do |span|
          response = post_json(url, payload, span)
          parsed = JSON.parse(response.body)
          raise "#{@provider_name} API error: #{parsed["error"]}" if parsed.include?("error")
          raise "#{@provider_name} API error: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

          parsed
        rescue JSON::ParserError => e
          span.add_event("#{@provider_name} API invalid JSON", attributes: { "exception.message" => e.message })
          raise "#{@provider_name} API returned invalid JSON"
        rescue Net::ReadTimeout, Net::OpenTimeout => e
          span.add_event("#{@provider_name} API timeout", attributes: { "exception.message" => e.message })
          raise "#{@provider_name} API timeout"
        end
      end

      private

      def post_json(url, payload, span)
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = Net::HTTP::Post.new(uri.request_uri)
        @headers.each { |key, value| request[key] = value }
        request.body = payload.to_json
        span.add_event("#{@provider_name} API call")

        response = http.request(request)
        span.set_attribute("http.status_code", response.code.to_i)
        span.add_event("#{@provider_name} API response")
        response
      end

      def telemetry_attributes(url, user)
        uri = URI.parse(url)
        {
          "http.url" => url,
          "http.scheme" => "https",
          "http.target" => uri.request_uri,
          "http.method" => "POST",
          "net.peer.name" => uri.host,
          "net.peer.port" => uri.port,
          "discord.user.hash" => anonymized_user_hash(user),
          "discord.user.bot_account" => user&.bot_account
        }
      end

      def anonymized_user_hash(user)
        return nil unless user

        Telemetry::Anonymizer.hash(user.id)
      end
    end
  end
end

require_relative "../open_mod_bot/compatibility"
