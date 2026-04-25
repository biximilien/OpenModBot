# ADR-014: Maintain Append-Only Event Store

_Status_: Accepted
_Context_:
LLM classification quality and scoring logic will improve over time. Historical replay and auditability depend on preserving the original interaction stream.

_Decision_:
`interaction_events` is append-only and immutable after initial persistence, except for narrowly scoped privacy lifecycle updates such as raw-content redaction after retention expiry.

_Clarifications_:

- Reclassification must create new classification records; it must not mutate historical interaction events
- Replay and rescoring pipelines consume stored events and write new derived artifacts
- Backfills may append newly discovered historical events, but must not rewrite the semantic content of existing event rows
- Classification lifecycle status may be tracked alongside events operationally, but the event payload itself remains the historical source record

_Consequences_:

- Enables full replay and auditability
- Keeps event history stable across classifier and scoring changes
- Requires separate handling for mutable operational metadata and derived projections
- Storage growth must be managed with explicit archival and retention strategies
