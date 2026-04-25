# ADR-024: Keep Scoring Logic Deterministic and Versioned

_Status_: Accepted
_Context_: Scoring functions will evolve.

_Decision_:

- Implement scoring as pure functions
- Version scoring algorithms
- Store `score_version` alongside computed derived values that depend on scoring logic
- Treat score versioning as distinct from classifier versioning
- Recomputing scores with a new score version must not overwrite historical classifier records

_Scope_:

- Relationship-edge projections that persist computed scores must carry `score_version`
- User-risk or similar aggregate projections must carry `score_version`
- Moderator-facing read APIs should surface the relevant `score_version` for explainability
- Stateless presentation-only formatting does not require its own score version

_Consequences_:

- Easier experimentation
- Enables rollback
- Requires recomputation when logic changes
- Makes score provenance inspectable during reviews and replays
