# ADR-013: Support Postgres as Durable Harassment Store with JSONB for Classification

_Status_: Accepted

_Current implementation note_:
The original decision kept Redis as a lightweight harassment storage backend during rollout. The current harassment plugin now requires the `postgres` plugin and uses Postgres-backed repositories at runtime. Redis-backed harassment repositories remain only for historical migration, verification, and older deployment support.

_Context_:
The harassment pipeline needs durable relational querying for time windows, tenant scoping, and projections, while still preserving flexible structured classifier payloads. During incremental rollout, the project also needed to keep a lightweight Redis-backed path for local development, simple deployments, and migration.

_Decision_:
Support PostgreSQL as the durable relational datastore for the harassment pipeline when the optional Postgres infrastructure plugin is enabled. Redis-backed harassment repositories may coexist behind the same domain contracts for migration and compatibility, but the harassment plugin runtime uses Postgres.

Postgres access is provided by the optional `postgres` plugin. The harassment plugin and runtime must not own global database connection setup directly; they receive the Postgres connection through plugin composition and repository construction.

When Postgres is enabled, preserve the logical split between immutable interaction events, immutable classification records, durable job state, cache/rate-limit support tables, and derived projections.

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

_classification_jobs_

- id (PK)
- guild_id
- message_id
- classifier_version
- status
- attempt_count
- available_at
- last_error_class
- last_error_message
- enqueued_at
- updated_at

_classification_cache_entries_

- cache_key (PK)
- record_payload JSONB
- expires_at

_server_rate_limits_

- guild_id (PK)
- timestamps JSONB

_Indexes_:

- unique `(guild_id, message_id)` on interaction events
- unique `(guild_id, message_id, classifier_version)` on classification records
- GIN or equivalent index for flexible classification JSONB access where justified
- indexes supporting tenant-scoped time-window queries, such as `(guild_id, author_id, created_at)`
- unique `(guild_id, source_user_id, target_user_id, score_version)` or an equivalent active-projection strategy for relationship edges
- indexes supporting due-job queries, such as `(status, available_at)`

_Consequences_:

- Preserves the event/classification split established in ADR-001
- Supports relational queries for moderation insights and replay orchestration
- Keeps database setup in the optional Postgres infrastructure plugin instead of hidden global connection setup
- Allows Redis and Postgres repository implementations to coexist behind the same domain contracts for migration
- Allows schema-flexible classifier payloads without collapsing immutable events into mutable records
- Requires careful indexing and projection design to avoid JSONB performance pitfalls
- Requires migration, verification, and cutover tooling between Redis-backed and Postgres-backed harassment state
