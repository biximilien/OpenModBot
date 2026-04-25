# ADR-013: Use Postgres as Primary Store with JSONB for Classification

_Status_: Accepted
_Context_:
The harassment pipeline needs durable relational querying for time windows, tenant scoping, and projections, while still preserving flexible structured classifier payloads.

_Decision_:
Use PostgreSQL as the primary durable datastore for the harassment pipeline. Preserve the logical split between immutable interaction events, immutable classification records, and derived projections.

_Logical schema_:

_interaction_events_

- id (PK)
- guild_id
- message_id
- author_id
- channel_id
- target_user_ids (array or join table)
- raw_content
- classification_status
- content_retention_expires_at
- content_redacted_at
- created_at

_classification_records_

- id (PK)
- guild_id
- message_id
- classifier_version
- model_version
- prompt_version
- classification JSONB
- severity_score
- confidence
- classified_at

_relationship_edges_

- id (PK)
- guild_id
- source_user_id
- target_user_id
- score_version
- hostility_score
- positive_score
- interaction_count
- last_interaction_at

_Indexes_:

- unique `(guild_id, message_id)` on interaction events
- unique `(guild_id, message_id, classifier_version)` on classification records
- GIN or equivalent index for flexible classification JSONB access where justified
- indexes supporting tenant-scoped time-window queries, such as `(guild_id, author_id, created_at)`
- unique `(guild_id, source_user_id, target_user_id, score_version)` or an equivalent active-projection strategy for relationship edges

_Consequences_:

- Preserves the event/classification split established in ADR-001
- Supports relational queries for moderation insights and replay orchestration
- Allows schema-flexible classifier payloads without collapsing immutable events into mutable records
- Requires careful indexing and projection design to avoid JSONB performance pitfalls
