module Moderation
  module RewritePersonalities
    DEFAULT = "objective".freeze
    INSTRUCTIONS = {
      "objective" => "Rewrite the user's message in a direct, neutral tone. State the concern plainly, avoid emotional language, preserve the user's apparent intent, do not add new claims, and return only the rewritten message.",
      "empathetic" => "Rewrite the user's message in a calm, empathetic tone. Acknowledge tension without validating harmful language, preserve the user's apparent intent, do not add new claims, and return only the rewritten message.",
      "teacher" => "Rewrite the user's message in a patient, lightly instructional tone. Clarify the concern without scolding, preserve the user's apparent intent, do not add new claims, and return only the rewritten message.",
      "supportive" => "Rewrite the user's message in a supportive, encouraging tone while keeping boundaries clear. Preserve the user's apparent intent, avoid harmful or inflammatory language, do not add new claims, and return only the rewritten message.",
      "formal" => "Rewrite the user's message in a polished, professional tone suitable for a workplace or formal community. Preserve the user's apparent intent, avoid emotional or inflammatory language, do not add new claims, and return only the rewritten message.",
      "concise" => "Rewrite the user's message as briefly as possible while keeping it respectful and clear. Preserve the user's apparent intent, do not add new claims, and return only the rewritten message.",
      "diplomatic" => "Rewrite the user's message in a tactful, de-escalating tone. Preserve the user's apparent intent, avoid blame and inflammatory language, do not add new claims, and return only the rewritten message.",
      "coach" => "Rewrite the user's message in a firm but constructive coaching tone. Preserve the user's apparent intent, focus on behavior or next steps rather than personal attacks, do not add new claims, and return only the rewritten message.",
      "plainspoken" => "Rewrite the user's message in simple, everyday language. Keep it respectful, direct, and easy to understand. Preserve the user's apparent intent, do not add new claims, and return only the rewritten message.",
      "legalistic" => "Rewrite the user's message in a careful, precise tone. Avoid emotional framing, insults, threats, and unsupported claims. Preserve the user's apparent intent and return only the rewritten message.",
      "community_manager" => "Rewrite the user's message in a calm community-manager tone. Emphasize respectful norms and constructive participation without sounding punitive. Preserve the user's apparent intent, do not add new claims, and return only the rewritten message.",
      "southern_charm" => "Rewrite the user's message in a lightly warm, polite Southern-inspired voice. Keep the language respectful and clear, avoid caricature, preserve the user's apparent intent, do not add new claims, and return only the rewritten message.",
      "shakespearean" => "Rewrite the user's message in a light Shakespearean style while keeping the meaning clear and respectful. Avoid obscure phrasing, insults, threats, and new claims. Preserve the user's apparent intent and return only the rewritten message.",
      "robot" => "Rewrite the user's message in a dry, literal robot-like voice while keeping it respectful and clear. Preserve the user's apparent intent, do not add threats, insults, or new claims, and return only the rewritten message.",
      "zen" => "Rewrite the user's message in a calm, minimal, de-escalating tone. Preserve the user's apparent intent, avoid blame and emotional language, do not add new claims, and return only the rewritten message.",
      "pirate" => "Rewrite the user's message in a light pirate voice while keeping it respectful and clear. Do not add threats, insults, or new claims. Preserve the user's apparent intent and return only the rewritten message.",
      "poetic" => "Rewrite the user's message in a concise poetic voice while keeping the meaning clear, respectful, and moderation-appropriate. Avoid obscure metaphors, do not add new claims, preserve the user's apparent intent, and return only the rewritten message.",
    }.freeze

    def self.fetch(name)
      INSTRUCTIONS.fetch(name, INSTRUCTIONS.fetch(DEFAULT))
    end

    def self.known?(name)
      INSTRUCTIONS.key?(name)
    end
  end
end
