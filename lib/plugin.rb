module ModerationGPT
  class Plugin
    def boot(**); end

    def ready(**); end

    def shutdown(**); end

    def message(**); end

    def moderation_result(**); end

    def infraction(**); end

    def automod_outcome(**); end

    def rewrite_instructions(**)
      nil
    end

    def moderation_strategies(**)
      []
    end

    def commands
      []
    end

    def ai_provider
      nil
    end

    def capabilities
      {}
    end

    def postgres_connection
      nil
    end
  end
end
