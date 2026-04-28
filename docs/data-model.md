# Data Model

ModerationGPT stores its original moderation state in Redis. Redis keys are defined in `DataModel::Keys`; JSON audit records are defined by `DataModel::KarmaEvent`.

## Keys

### `servers`

- Type: Redis set
- Members: Discord server IDs as strings
- Purpose: tracks servers known to the bot

### `server_{server_id}_users`

- Type: Redis set
- Members: Discord user IDs as strings
- Purpose: stores the per-server moderation watchlist

### `server_{server_id}_karma`

- Type: Redis hash
- Fields: Discord user IDs as strings
- Values: integer karma scores
- Purpose: stores current per-server user karma

### `server_{server_id}_user_{user_id}_karma_history`

- Type: Redis list
- Values: JSON `KarmaEvent` records
- Order: newest first
- Retention: latest 50 entries
- Purpose: stores score changes and automod outcomes for one user in one server

### `server_{server_id}_moderation_review`

- Type: Redis list
- Values: JSON moderation review records
- Order: newest first
- Retention: latest 100 entries
- Purpose: stores recent live and shadow-mode moderation decisions for moderator review

### `harassment_interaction_events`

- Type: Redis hash
- Fields: `{server_id}:{message_id}`
- Values: JSON `Harassment::InteractionEvent` records
- Purpose: stores immutable harassment interaction events, including classification lifecycle state and content retention metadata

### `harassment_classification_records`

- Type: Redis hash
- Fields: `{server_id}:{message_id}:{classifier_version}`
- Values: JSON `Harassment::ClassificationRecord` records
- Purpose: stores immutable structured classifier output for harassment analysis

### `harassment_classification_jobs`

- Type: Redis hash
- Fields: `{server_id}:{message_id}:{classifier_version}`
- Values: JSON `Harassment::ClassificationJob` records
- Purpose: stores idempotent harassment classification job state, retry metadata, and availability timestamps

### `harassment_classification_cache`

- Type: Redis hash
- Fields: `harassment-cache:{sha256}`
- Values: JSON entries containing an expiration timestamp and cached `Harassment::ClassificationRecord`
- Purpose: caches structured classifier output by server, classifier identity, and normalized message/context input

### `harassment_server_rate_limits`

- Type: Redis hash
- Fields: Discord server IDs as strings
- Values: JSON arrays of recent classifier-call timestamps
- Purpose: tracks per-server classifier throughput so heavy processing can be deferred without losing jobs

## Harassment Storage Backend

The harassment runtime can store its own pipeline state in either Redis or Postgres, depending on `HARASSMENT_STORAGE_BACKEND`.

- `redis`:
  uses the Redis keys above for interaction events, classification records, classification jobs, classifier cache entries, and server rate limits
- `postgres`:
  uses the tables in `db/harassment/001_initial_schema.sql` for:
  - `interaction_events`
  - `classification_records`
  - `classification_jobs`
  - `classification_cache_entries`
  - `server_rate_limits`
  - `relationship_edges`

Postgres storage also requires the optional `postgres` plugin to be enabled so the runtime can use the shared database connection.

The Redis-to-Postgres bootstrap path migrates interaction events, classification records, and classification jobs. Cache, rate-limit, and relationship-edge projection state are not bootstrapped.

## KarmaEvent

```json
{
  "schema_version": 1,
  "created_at": "2026-04-20T12:00:00Z",
  "delta": -1,
  "score": -5,
  "source": "automated_infraction",
  "actor_id": 42,
  "reason": "appeal"
}
```

`actor_id` and `reason` are optional. Automod outcome events use `delta: 0` with the current score.

Common sources:

- `automated_infraction`
- `manual_adjustment`
- `manual_reset`
- `automod_log_only`
- `automod_timeout_applied`
- `automod_timeout_unavailable`
- `automod_kick_applied`
- `automod_kick_unavailable`
- `automod_ban_applied`
- `automod_ban_unavailable`
- `automod_skipped_elevated_member`

## ModerationReviewEntry

```json
{
  "created_at": "2026-04-20T12:00:00Z",
  "server_id": "42",
  "channel_id": "77",
  "message_id": "1234567890",
  "user_id": "100",
  "strategy": "RemoveMessageStrategy",
  "action": "would_remove",
  "shadow_mode": true,
  "flagged": true,
  "categories": {
    "harassment": true
  },
  "category_scores": {
    "harassment": 0.91
  },
  "rewrite": "Please keep this respectful.",
  "original_content": "go away",
  "automod_outcome": "automod_timeout_applied"
}
```

`rewrite`, `original_content`, and `automod_outcome` are optional. `original_content` is only stored when `MODERATION_REVIEW_STORE_CONTENT=true`. Shadow-mode entries use `would_remove` or `would_rewrite` actions and do not mutate messages, karma, or automod state.

## Harassment InteractionEvent

```json
{
  "message_id": "1234567890",
  "server_id": "42",
  "channel_id": "77",
  "author_id": "100",
  "target_user_ids": ["200", "300"],
  "timestamp": "2026-04-25T12:00:00Z",
  "raw_content": "leave them alone",
  "classification_status": "pending",
  "content_retention_expires_at": "2026-05-25T12:00:00Z",
  "content_redacted_at": null
}
```

Notes:

- `classification_status` is one of `pending`, `classified`, `failed_retryable`, or `failed_terminal`
- `raw_content` may later be replaced with a redacted placeholder after the retention period expires
- context for classifier prompts is assembled transiently from stored events and is not itself persisted as a separate record

## Harassment ClassificationRecord

```json
{
  "server_id": "42",
  "message_id": "1234567890",
  "classifier_version": "harassment-v1",
  "model_version": "gpt-4o-2024-08-06",
  "prompt_version": "harassment-prompt-v1",
  "classification": {
    "intent": "aggressive",
    "target_type": "individual",
    "toxicity_dimensions": {
      "insult": true,
      "threat": false,
      "profanity": true,
      "exclusion": false,
      "harassment": true
    }
  },
  "severity_score": 0.82,
  "confidence": 0.74,
  "classified_at": "2026-04-25T12:00:05Z"
}
```

## Harassment ClassificationJob

```json
{
  "server_id": "42",
  "message_id": "1234567890",
  "classifier_version": "harassment-v1",
  "status": "pending",
  "attempt_count": 0,
  "available_at": "2026-04-25T12:00:00Z",
  "last_error_class": null,
  "last_error_message": null,
  "enqueued_at": "2026-04-25T12:00:00Z",
  "updated_at": "2026-04-25T12:00:00Z"
}
```

Notes:

- job keys are idempotent by `server_id`, `message_id`, and `classifier_version`
- retries update the same job record rather than creating duplicates
- failed jobs remain queryable for operational review
- rate-limit deferrals keep the same job record in `pending` state and move `available_at` forward without incrementing `attempt_count`
