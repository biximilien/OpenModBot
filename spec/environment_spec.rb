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
      ENV["DISCORD_BOT_TOKEN"] = "discord"
      ENV["REDIS_URL"] = "redis://localhost:6379/0"

      expect { described_class.validate! }.to raise_error(
        RuntimeError,
        "Missing required environment variables: OPENAI_API_KEY",
      )
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

      expect(described_class.telemetry_enabled?).to eq(false)
    end

    it "is true when configured" do
      ENV["TELEMETRY_ENABLED"] = "true"

      expect(described_class.telemetry_enabled?).to eq(true)
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

    it "adds telemetry when telemetry is enabled" do
      ENV.delete("PLUGINS")
      ENV["TELEMETRY_ENABLED"] = "true"

      expect(described_class.enabled_plugins).to eq(["telemetry"])
    end

    it "deduplicates telemetry when configured twice" do
      ENV["PLUGINS"] = "telemetry"
      ENV["TELEMETRY_ENABLED"] = "true"

      expect(described_class.enabled_plugins).to eq(["telemetry"])
    end
  end

  describe ".plugin_requires" do
    it "returns no plugin requires by default" do
      ENV.delete("PLUGIN_REQUIRES")

      expect(described_class.plugin_requires).to eq([])
    end

    it "parses comma-separated require paths" do
      ENV["PLUGIN_REQUIRES"] = "moderation_gpt/plugins/audit_webhook, custom/plugin"

      expect(described_class.plugin_requires).to eq([
        "moderation_gpt/plugins/audit_webhook",
        "custom/plugin",
      ])
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

      expect(described_class.log_invite_url?).to eq(false)
    end

    it "is true when configured" do
      ENV["LOG_INVITE_URL"] = "true"

      expect(described_class.log_invite_url?).to eq(true)
    end
  end
end
