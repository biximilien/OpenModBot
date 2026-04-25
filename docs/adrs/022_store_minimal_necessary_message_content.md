# ADR-022: Store Minimal Necessary Message Content

_Status_: Accepted
_Context_: Privacy concerns increase with full message retention.

_Decision_:
Store:

- raw content for the minimum period required for classification, replay, and moderator review
- hashed or redacted content for longer-lived operational records when raw content is no longer justified

_Retention policy_:

- Default raw-content retention is 30 days, matching ADR-011
- Deployments may shorten that window, but must not silently extend it without an explicit policy change
- After the retention window expires, raw content must be deleted or irreversibly redacted while preserving non-content metadata and derived state
- Long-lived stored artifacts should retain only the minimum representation needed for auditability, replay coordination, and operational review

_Consequences_:

- Better privacy posture
- Limits ability to re-evaluate nuanced context later
- Requires data lifecycle policies
- Must remain consistent with ADR-011 privacy disclosures
