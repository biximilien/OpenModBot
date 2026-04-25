# ADR-015: Version LLM Prompts and Outputs

_Status_: Accepted
_Context_:
Changes to prompts, schemas, or models can alter classification behavior significantly. Replay and explainability require those changes to be traceable.

_Decision_:
Every classification record must carry explicit classifier lineage metadata.

_Required fields_:

- `classifier_version`: the authoritative semantic version for the end-to-end classifier contract
- `model_version`: the external model identifier used for that classification
- `prompt_version`: the internal prompt/schema contract version

_Versioning rules_:

- `classifier_version` is the primary replay and idempotency key used outside the classifier implementation
- `prompt_version` changes when prompt instructions, context construction rules, or output schema expectations change
- `model_version` records the external model dependency even when the prompt contract remains the same
- A new `classifier_version` should be issued whenever a change can materially alter classification output semantics

_Storage_:

- Prompt definitions and schema definitions must live in versioned code or configuration
- Historical classification records must preserve the exact version metadata that produced them

_Consequences_:

- Enables reproducibility and explainability
- Supports A/B testing and controlled replay
- Prevents "same version, different behavior" drift
- Requires explicit migration and replay strategy for older classifications
