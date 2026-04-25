# ADR-016: Enforce Strict JSON Schema for LLM Output

_Status_: Accepted
_Context_: LLMs may produce inconsistent outputs unless constrained.

_Decision_:
Use schema-constrained prompting and strict validation for classifier output.

_Rules_:

- Classifier responses must be JSON-only
- Responses must be validated against the expected schema before persistence
- Invalid outputs must never be persisted as authoritative classification records
- Schema violations caused by malformed model output should be treated as retryable up to bounded retry limits unless there is evidence the request contract itself is invalid
- Deterministic local validation failures caused by misconfiguration, missing schema definitions, or incompatible contract wiring should be treated as terminal

_Operational implication_:

- Retry vs terminal failure must be surfaced through the classification lifecycle defined in ADR-012
- Failed validation attempts must remain observable for operator review

_Consequences_:

- Increased reliability and downstream determinism
- Slight latency and cost increase when retries are needed
- Requires an explicit validation layer and clear failure classification
