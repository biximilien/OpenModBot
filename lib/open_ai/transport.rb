require "json"
require "net/http"
require "uri"
require_relative "../../environment"
require_relative "../telemetry"

module OpenAI
  class Transport
    def initialize(api_key: Environment.openai_api_key)
      @api_key = api_key
    end

    def query(url, params, user = nil)
      Telemetry.in_span(url, attributes: telemetry_attributes(url, user)) do |span|
        begin
          response = post_json(url, params, span)
          parsed = JSON.parse(response.body)
          raise "OpenAI API error: #{parsed['error']}" if parsed.include?("error")
          raise "OpenAI API error: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

          parsed
        rescue JSON::ParserError => e
          span.add_event("OpenAI API invalid JSON", attributes: { "exception.message" => e.message })
          raise "OpenAI API returned invalid JSON"
        rescue Net::ReadTimeout, Net::OpenTimeout => e
          span.add_event("OpenAI API timeout", attributes: { "exception.message" => e.message })
          raise "OpenAI API timeout"
        end
      end
    end

    private

    def post_json(url, params, span)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/json"
      request["Authorization"] = "Bearer #{@api_key}"
      request.body = params.to_json
      span.add_event("OpenAI API call")

      response = http.request(request)
      span.set_attribute("http.status_code", response.code.to_i)
      span.add_event("OpenAI API response")
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
        "discord.user.bot_account" => user&.bot_account,
      }
    end

    def anonymized_user_hash(user)
      return nil unless user

      Telemetry::Anonymizer.hash(user.id)
    end
  end
end
