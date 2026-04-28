module ModerationGPT
  module AI
    class Provider
      def moderate_text(_text, _user = nil)
        raise NotImplementedError, "#{self.class} must implement #moderate_text"
      end

      def moderation_rewrite(_text, _user = nil, instructions:)
        raise NotImplementedError, "#{self.class} must implement #moderation_rewrite"
      end

      def generate_structured(prompt:, schema:, model: nil, instructions: nil, schema_name: nil, user: nil)
        raise NotImplementedError, "#{self.class} must implement #generate_structured"
      end

      def query(_url, _params, _user = nil)
        raise NotImplementedError, "#{self.class} must implement #query"
      end

      def response_text(_response)
        raise NotImplementedError, "#{self.class} must implement #response_text"
      end
    end
  end
end
