# ADR-021: Use Background Workers for All Heavy Processing

_Status_: Accepted
_Context_: Discord bots must remain responsive; blocking operations degrade UX.

_Decision_:
Use background job processing (e.g., Sidekiq):

- classification
- projection updates derived from stored classification records
- reprocessing

_Scope clarification_:

- Discord message ingestion remains synchronous and lightweight
- Raw interaction events may be stored inline with ingestion
- Expensive or retryable work must happen off the Discord gateway path
- The authoritative synchronization boundary is the stored classification record
- Read-model projections are eventually consistent with stored classification records

_Current implementation note_:

- An in-process background worker thread is acceptable as a transitional implementation
- The target architecture remains explicit worker infrastructure with monitoring, retry handling, and operational visibility

_Consequences_:

- Improved responsiveness
- Eventual consistency
- Requires monitoring and retry handling
- Requires explicit ownership of worker lifecycle and projection semantics
