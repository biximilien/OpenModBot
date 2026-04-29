module OpenModBot
  module AI
    class ProviderConfig
      DEFAULT_PROVIDER = "openai".freeze
      PROVIDERS = {
        "openai" => {
          api_key_variable: "OPENAI_API_KEY",
          classifier_model: "gpt-4o-2024-08-06"
        },
        "google_ai" => {
          api_key_variable: "GOOGLE_AI_API_KEY",
          classifier_model: -> { Environment.google_ai_model }
        }
      }.freeze

      def initialize(enabled_plugins:)
        @enabled_plugins = enabled_plugins
      end

      def provider_name
        @enabled_plugins.reverse_each do |plugin|
          return plugin if PROVIDERS.key?(plugin)
        end

        DEFAULT_PROVIDER
      end

      def api_key_variable
        provider.fetch(:api_key_variable)
      end

      def classifier_model
        model = provider.fetch(:classifier_model)
        model.respond_to?(:call) ? model.call : model
      end

      private

      def provider
        PROVIDERS.fetch(provider_name)
      end
    end
  end
end
