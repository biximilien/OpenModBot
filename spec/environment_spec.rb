describe Environment do
  around do |example|
    original = ENV.to_h
    example.run
  ensure
    ENV.replace(original)
  end

  describe ".validate!" do
    it "passes when required variables are present" do
      ENV["OPENAI_API_KEY"] = "openai"
      ENV["DISCORD_BOT_TOKEN"] = "discord"
      ENV["REDIS_URL"] = "redis://localhost:6379/0"

      expect { described_class.validate! }.not_to raise_error
    end

    it "raises with missing required variables" do
      ENV.delete("OPENAI_API_KEY")
      ENV.delete("PLUGINS")
      ENV["DISCORD_BOT_TOKEN"] = "discord"
      ENV["REDIS_URL"] = "redis://localhost:6379/0"

      expect { described_class.validate! }.to raise_error(
        RuntimeError,
        "Missing required environment variables: OPENAI_API_KEY"
      )
    end

    it "requires the Google AI key when Google AI is the configured provider" do
      ENV.delete("OPENAI_API_KEY")
      ENV.delete("GOOGLE_AI_API_KEY")
      ENV["PLUGINS"] = "google_ai"
      ENV["DISCORD_BOT_TOKEN"] = "discord"
      ENV["REDIS_URL"] = "redis://localhost:6379/0"

      expect { described_class.validate! }.to raise_error(
        RuntimeError,
        "Missing required environment variables: GOOGLE_AI_API_KEY"
      )
    end

    it "passes without an OpenAI key when Google AI has the required key" do
      ENV.delete("OPENAI_API_KEY")
      ENV["GOOGLE_AI_API_KEY"] = "google"
      ENV["PLUGINS"] = "google_ai"
      ENV["DISCORD_BOT_TOKEN"] = "discord"
      ENV["REDIS_URL"] = "redis://localhost:6379/0"

      expect { described_class.validate! }.not_to raise_error
    end
  end

  describe ".openai_moderation_model" do
    it "returns the default model" do
      ENV.delete("OPENAI_MODERATION_MODEL")

      expect(described_class.openai_moderation_model).to eq("omni-moderation-latest")
    end
  end

  describe ".openai_rewrite_model" do
    it "returns the default model" do
      ENV.delete("OPENAI_REWRITE_MODEL")

      expect(described_class.openai_rewrite_model).to eq("gpt-4.1-mini")
    end
  end

  describe ".google_ai_api_key" do
    it "returns the configured Google AI API key" do
      ENV["GOOGLE_AI_API_KEY"] = "google-key"

      expect(described_class.google_ai_api_key).to eq("google-key")
    end
  end

  describe ".google_ai_model" do
    it "returns the default Google AI model" do
      ENV.delete("GOOGLE_AI_MODEL")

      expect(described_class.google_ai_model).to eq("gemini-2.5-flash")
    end

    it "returns the configured Google AI model" do
      ENV["GOOGLE_AI_MODEL"] = "gemini-test"

      expect(described_class.google_ai_model).to eq("gemini-test")
    end
  end

  describe ".harassment_classifier_model" do
    it "returns the default model" do
      ENV.delete("HARASSMENT_CLASSIFIER_MODEL")
      ENV.delete("PLUGINS")

      expect(described_class.harassment_classifier_model).to eq("gpt-4o-2024-08-06")
    end

    it "returns a configured model" do
      ENV["HARASSMENT_CLASSIFIER_MODEL"] = "gpt-4o-mini"

      expect(described_class.harassment_classifier_model).to eq("gpt-4o-mini")
    end

    it "defaults to the Google AI model when Google AI is the configured provider" do
      ENV.delete("HARASSMENT_CLASSIFIER_MODEL")
      ENV["GOOGLE_AI_MODEL"] = "gemini-test"
      ENV["PLUGINS"] = "google_ai"

      expect(described_class.harassment_classifier_model).to eq("gemini-test")
    end
  end

  describe ".harassment_classifier_cache_ttl_seconds" do
    it "returns the default ttl" do
      ENV.delete("HARASSMENT_CLASSIFIER_CACHE_TTL_SECONDS")

      expect(described_class.harassment_classifier_cache_ttl_seconds).to eq(3_600)
    end
  end

  describe ".harassment_classifier_rate_limit_per_minute" do
    it "returns the default limit" do
      ENV.delete("HARASSMENT_CLASSIFIER_RATE_LIMIT_PER_MINUTE")

      expect(described_class.harassment_classifier_rate_limit_per_minute).to eq(30)
    end
  end

  describe ".harassment_storage_backend" do
    it "defaults to redis" do
      ENV.delete("HARASSMENT_STORAGE_BACKEND")

      expect(described_class.harassment_storage_backend).to eq("redis")
    end

    it "returns postgres when configured" do
      ENV["HARASSMENT_STORAGE_BACKEND"] = "postgres"

      expect(described_class.harassment_storage_backend).to eq("postgres")
    end

    it "falls back to redis for unknown values" do
      ENV["HARASSMENT_STORAGE_BACKEND"] = "mystery"

      expect(described_class.harassment_storage_backend).to eq("redis")
    end
  end

  describe ".karma_automod_threshold" do
    it "returns the default threshold" do
      ENV.delete("KARMA_AUTOMOD_THRESHOLD")

      expect(described_class.karma_automod_threshold).to eq(-5)
    end

    it "returns a configured threshold" do
      ENV["KARMA_AUTOMOD_THRESHOLD"] = "-10"

      expect(described_class.karma_automod_threshold).to eq(-10)
    end
  end

  describe ".telemetry_hash_salt" do
    it "returns the default salt" do
      ENV.delete("TELEMETRY_HASH_SALT")

      expect(described_class.telemetry_hash_salt).to eq("development-telemetry-salt")
    end

    it "returns a configured salt" do
      ENV["TELEMETRY_HASH_SALT"] = "deployment-secret"

      expect(described_class.telemetry_hash_salt).to eq("deployment-secret")
    end
  end

  describe ".telemetry_enabled?" do
    it "is false by default" do
      ENV.delete("TELEMETRY_ENABLED")

      expect(described_class.telemetry_enabled?).to be(false)
    end

    it "is true when configured" do
      ENV["TELEMETRY_ENABLED"] = "true"

      expect(described_class.telemetry_enabled?).to be(true)
    end
  end

  describe ".enabled_plugins" do
    it "returns no plugins by default" do
      ENV.delete("PLUGINS")
      ENV.delete("TELEMETRY_ENABLED")

      expect(described_class.enabled_plugins).to eq([])
    end

    it "parses comma-separated plugins" do
      ENV["PLUGINS"] = "telemetry, audit_webhook"

      expect(described_class.enabled_plugins).to eq(%w[telemetry audit_webhook])
    end

    it "does not implicitly add telemetry when telemetry is enabled" do
      ENV.delete("PLUGINS")
      ENV["TELEMETRY_ENABLED"] = "true"

      expect(described_class.enabled_plugins).to eq([])
    end

    it "deduplicates configured plugins" do
      ENV["PLUGINS"] = "telemetry, telemetry"

      expect(described_class.enabled_plugins).to eq(["telemetry"])
    end
  end

  describe ".plugin_requires" do
    it "returns no plugin requires by default" do
      ENV.delete("PLUGIN_REQUIRES")

      expect(described_class.plugin_requires).to eq([])
    end

    it "parses comma-separated require paths" do
      ENV["PLUGIN_REQUIRES"] = "open_mod_bot/plugins/audit_webhook, custom/plugin"

      expect(described_class.plugin_requires).to eq([
                                                      "open_mod_bot/plugins/audit_webhook",
                                                      "custom/plugin"
                                                    ])
    end
  end

  describe ".personality" do
    it "returns objective by default" do
      ENV.delete("PERSONALITY")

      expect(described_class.personality).to eq("objective")
    end

    it "normalizes configured personalities" do
      ENV["PERSONALITY"] = "Empathetic"

      expect(described_class.personality).to eq("empathetic")
    end
  end

  describe ".karma_automod_action" do
    it "returns timeout by default" do
      ENV.delete("KARMA_AUTOMOD_ACTION")

      expect(described_class.karma_automod_action).to eq("timeout")
    end

    it "returns a configured action" do
      ENV["KARMA_AUTOMOD_ACTION"] = "ban"

      expect(described_class.karma_automod_action).to eq("ban")
    end
  end

  describe ".karma_timeout_seconds" do
    it "returns the default timeout" do
      ENV.delete("KARMA_TIMEOUT_SECONDS")

      expect(described_class.karma_timeout_seconds).to eq(3_600)
    end

    it "returns a configured timeout" do
      ENV["KARMA_TIMEOUT_SECONDS"] = "120"

      expect(described_class.karma_timeout_seconds).to eq(120)
    end
  end

  describe ".log_invite_url?" do
    it "is false by default" do
      ENV.delete("LOG_INVITE_URL")

      expect(described_class.log_invite_url?).to be(false)
    end

    it "is true when configured" do
      ENV["LOG_INVITE_URL"] = "true"

      expect(described_class.log_invite_url?).to be(true)
    end
  end

  describe ".log_format" do
    it "defaults to json" do
      ENV.delete("LOG_FORMAT")

      expect(described_class.log_format).to eq("json")
    end

    it "returns a configured format" do
      ENV["LOG_FORMAT"] = "plain"

      expect(described_class.log_format).to eq("plain")
    end

    it "falls back to json for unknown formats" do
      ENV["LOG_FORMAT"] = "xml"

      expect(described_class.log_format).to eq("json")
    end
  end

  describe ".moderation_shadow_mode?" do
    it "is false by default" do
      ENV.delete("MODERATION_SHADOW_MODE")

      expect(described_class.moderation_shadow_mode?).to be(false)
    end

    it "is true when configured" do
      ENV["MODERATION_SHADOW_MODE"] = "true"

      expect(described_class.moderation_shadow_mode?).to be(true)
    end
  end

  describe ".moderation_shadow_rewrite?" do
    it "is true by default" do
      ENV.delete("MODERATION_SHADOW_REWRITE")

      expect(described_class.moderation_shadow_rewrite?).to be(true)
    end

    it "is false when configured" do
      ENV["MODERATION_SHADOW_REWRITE"] = "false"

      expect(described_class.moderation_shadow_rewrite?).to be(false)
    end
  end

  describe ".moderation_review_store_content?" do
    it "is false by default" do
      ENV.delete("MODERATION_REVIEW_STORE_CONTENT")

      expect(described_class.moderation_review_store_content?).to be(false)
    end

    it "is true when configured" do
      ENV["MODERATION_REVIEW_STORE_CONTENT"] = "true"

      expect(described_class.moderation_review_store_content?).to be(true)
    end
  end
end
