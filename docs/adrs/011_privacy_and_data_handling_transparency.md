# ADR-011: Privacy and Data Handling Transparency

_Status_: Accepted
_Context_: Messages are sent to external services for classification.

_Decision_: The system will apply the following privacy and data handling policies:

- Raw message content may be stored in the event store only for the minimum period needed for classification, replay, and moderator review.
- Default retention for raw content is 30 days. After expiration, raw content must be deleted or irreversibly redacted while preserving non-content metadata and derived scores.
- Deployments may shorten the raw-content retention window, but must not silently extend it without an explicit policy change.
- Long-lived operational records should retain only the minimum representation needed for auditability, replay coordination, and operational review.
- Discord identifiers may be stored internally when operationally required, but raw Discord IDs must not be sent to external LLM providers.
- External classification requests may include message content and limited contextual message excerpts, but must use pseudonymous participant labels rather than usernames or raw IDs.
- Classification context must be assembled transiently from retained events; the fully assembled prompt context must not be stored as a separate long-lived artifact.
- Documentation and operator-facing configuration must clearly disclose:
  - what is stored
  - how long it is retained
  - what is sent to external classifiers
  - whether manual review surfaces expose raw content

_Consequences_:

- Required for commercialization
- May limit data retention strategies
- Adds compliance overhead
- Forces retention and redaction behavior to be explicit in implementation
- Limits ability to re-evaluate nuanced context after raw content has expired
