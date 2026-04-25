# ADR-017: Support Reclassification Pipelines

_Status_: Accepted
_Context_: You will want to improve classifier behavior and recompute derived moderation insights over time.

_Decision_:
Support explicit replay pipelines for both reclassification and rescoring.

_Pipeline types_:

- `reclassification`: re-run classifier logic for stored interaction events using a new `classifier_version`
- `rescoring`: recompute derived projections using existing classification records and a new `score_version`

_Rules_:

- Reclassification and rescoring are distinct workflows and may advance independently
- Reclassification writes new classification records; it does not mutate historical records
- Rescoring writes new or replacement derived projections according to the active projection strategy; it does not mutate historical classifier records
- Both workflows must be idempotent and safe to resume after interruption
- Replay units must remain tenant-scoped and version-aware

_Consequences_:

- Enables continuous improvement without rewriting history
- Keeps classifier lineage and score lineage separate and inspectable
- Requires careful operational controls because replay can be expensive in cost and compute
