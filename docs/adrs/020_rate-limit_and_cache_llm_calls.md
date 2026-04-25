# ADR-020: Rate-Limit and Cache LLM Calls

_Status_: Accepted
_Context_: LLM usage is cost-sensitive and latency-bound.

_Decision_:

- Cache classification outputs, not derived harassment scores
- Deduplicate repeated classification requests when the semantic classifier inputs are identical
- Apply rate limiting per guild for outbound classifier requests
- Cache keys must include:
  - classifier version
  - prompt/schema version
  - normalized hash of message content and assembled context window
  - any guild-scoped classifier policy inputs if those inputs affect the request payload
- Cache hits must be treated as valid only for the exact classifier contract that produced them
- Reclassification with a new classifier version or prompt/schema version must bypass prior cache entries and write fresh classification records

_Consequences_:

- Reduced cost
- Faster response for repeated content
- Cache invalidation complexity
- Requires explicit cache-key versioning
- Prevents stale classifier results from leaking across prompt/schema changes
