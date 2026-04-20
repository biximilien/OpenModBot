require "json"
require "net/http"
require "uri"
require "opentelemetry/sdk"
require_relative "../environment"
require_relative "telemetry/anonymizer"
OpenAITracer = OpenTelemetry.tracer_provider.tracer("openai", "1.0")

module OpenAI
  ModerationResult = Struct.new(:flagged, :categories, :category_scores, keyword_init: true)

  def query(url, params, user = nil)
    OpenAITracer.in_span(url, attributes: {
                                "http.url" => url,
                                "http.scheme" => "https",
                                "http.target" => URI.parse(url).request_uri,
                                "http.method" => "POST",
                                "net.peer.name" => URI.parse(url).host,
                                "net.peer.port" => URI.parse(url).port,
                                "discord.user.hash" => anonymized_user_hash(user),
                                "discord.user.bot_account" => user&.bot_account,
                              }) do |span|
      begin
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = Net::HTTP::Post.new(uri.request_uri)
        request["Content-Type"] = "application/json"
        request["Authorization"] = "Bearer #{Environment.openai_api_key}"
        request.body = params.to_json
        span.add_event("OpenAI API call")

        response = http.request(request)
        span.set_attribute("http.status_code", response.code.to_i)
        span.add_event("OpenAI API response")

        ret = JSON.parse(response.body)
        raise "OpenAI API error: #{ret['error']}" if ret.include?("error")
        raise "OpenAI API error: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        ret
      rescue JSON::ParserError => e
        span.add_event("OpenAI API invalid JSON", attributes: { "exception.message" => e.message })
        raise "OpenAI API returned invalid JSON"
      rescue Net::ReadTimeout, Net::OpenTimeout => e
        span.add_event("OpenAI API timeout", attributes: { "exception.message" => e.message })
        raise "OpenAI API timeout"
      end
    end
  end

  def moderate_text(text, user = nil)
    response = query("https://api.openai.com/v1/moderations", {
      model: Environment.openai_moderation_model,
      input: text,
    }, user)

    result = response.fetch("results").first
    ModerationResult.new(
      flagged: result.fetch("flagged"),
      categories: result.fetch("categories"),
      category_scores: result.fetch("category_scores"),
    )
  end

  def moderation_rewrite(text, user = nil)
    response = query("https://api.openai.com/v1/responses", {
      model: Environment.openai_rewrite_model,
      instructions: "Rewrite the user's message in a respectful, constructive tone. Preserve the user's apparent intent, do not add new claims, and return only the rewritten message.",
      input: text,
    }, user)

    response_text(response)
  end

  def response_text(response)
    return response["output_text"].strip if response["output_text"]

    response.fetch("output", []).flat_map do |item|
      item.fetch("content", []).map { |content| content["text"] }
    end.compact.join.strip
  end

  def anonymized_user_hash(user)
    return nil unless user

    Telemetry::Anonymizer.hash(user.id)
  end
end
