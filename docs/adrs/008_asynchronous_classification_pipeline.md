# ADR-008: Process Classification and Heavy Work Asynchronously

_Status_: Accepted
_Context_: LLM calls are slow and rate-limited. Discord bots must remain responsive; blocking operations on the gateway path degrade UX and increase operational risk.

_Decision_: Process classification and other expensive or retryable harassment-domain work asynchronously:

- Ingest message -> enqueue job
- Worker calls GPT-4o
- Store classification result
- Track job state durably enough to support retries, deferrals, and operational review

This applies to:

- classification
- projection updates derived from stored classification records
- reclassification and rescoring workflows

_Ownership_:

- Core platform owns queueing, retries, and durable status tracking
- Plugins consume the resulting classification records and update their own projections

_Scope clarification_:

- Discord message ingestion remains synchronous and lightweight
- Raw interaction events may be stored inline with ingestion
- Expensive or retryable work must happen off the Discord gateway path
- The authoritative synchronization boundary is the stored classification record
- Read-model projections are eventually consistent with stored classification records

_Implementation path_:

- An in-process background worker thread is acceptable as a transitional implementation
- The target architecture remains explicit worker infrastructure with monitoring, retry handling, and operational visibility
- Sidekiq or equivalent infrastructure may be introduced when operational needs justify it

_Consequences_:

- Non-blocking message handling
- Eventual consistency
- Requires durable job state and background execution infrastructure; this may start as an in-process worker and later move to Sidekiq or equivalent
- Requires monitoring and explicit ownership of worker lifecycle and projection semantics
