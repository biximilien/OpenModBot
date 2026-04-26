# ADR-001: Represent User Interactions as Append-Only Events

_Status_: Accepted
_Context_: Harassment detection requires analyzing patterns over time. A simple "user-to-user state" model loses temporal resolution and makes reprocessing difficult. Raw interaction events, classification outputs, and derived relationship metrics evolve at different cadences and serve different operational purposes.

_Decision_: All Discord messages will be modeled as immutable interaction events. Classification output is not embedded directly into the base interaction record; it is stored as a separate immutable classification record keyed by `server_id`, `message_id`, and `classifier_version`.

The harassment domain maintains three distinct stores:

- Event store: append-only interaction records
- Classification store: immutable classifier outputs, versioned by classifier lineage
- Derived store: recomputable projections such as relationship edges and risk scores

`interaction_events` is append-only and immutable after initial persistence, except for narrowly scoped privacy lifecycle updates such as raw-content redaction after retention expiry.

_Schema (logical)_:

- message_id
- server_id
- channel_id
- author_id
- target_user_ids
- timestamp
- raw_content
- classification_status
- content_retention_expires_at

_Related classification record_:

- message_id
- classifier_version
- server_id
- classification (JSON)
- severity_score
- confidence
- classified_at

_Derived state_:

- Relationship edges and scores are derived from stored events and classification records
- Derived projections may be rebuilt when classifier or scoring logic changes
- Projection updates must not rewrite historical interaction events or classifier records

_Clarifications_:

- Reclassification creates new classification records; it must not mutate historical interaction events
- Replay and rescoring pipelines consume stored events and write new derived artifacts
- Backfills may append newly discovered historical events, but must not rewrite the semantic content of existing event rows
- Classification lifecycle status may be tracked alongside events operationally, but the event payload remains the historical source record

_Consequences_:

- Enables reprocessing with improved models
- Supports time-based analysis and decay
- Increased storage footprint
- Keeps ingestion separate from classification lifecycle
- Supports recomputation when models or scoring rules change
- Requires synchronization between stored classifications and derived projections
- Storage growth must be managed with explicit archival and retention strategies
