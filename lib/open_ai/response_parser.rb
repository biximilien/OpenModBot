module OpenAI
  class ResponseParser
    def self.text(response)
      return response["output_text"].strip if response["output_text"]

      response.fetch("output", []).flat_map do |item|
        item.fetch("content", []).map { |content| content["text"] }
      end.compact.join.strip
    end
  end
end
