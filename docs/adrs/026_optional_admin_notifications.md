# ADR-026: Optional Admin Notifications for Moderator Attention

_Status_: Proposed

_Context_:
Moderators need timely visibility when the bot sees something that should be reviewed by a human. Some notifications can come from core moderation, such as ambiguous classifier output or shadow-mode actions. Others can come from optional domain plugins, such as harassment risk signals or future incident detectors.

Notifications should not make the core bot depend on a specific delivery mechanism, persistence backend, or domain plugin. They should also not become automated enforcement. The notification surface is an operator attention mechanism: it asks a moderator to review something.

_Decision_:
Add admin notification as an optional feature plugin.

The notification plugin should observe existing plugin hooks and derived review data before introducing new core coupling. Initial notification sources may include:

- moderation results whose category scores fall into an ambiguous range
- shadow-mode moderation decisions
- automod threshold outcomes
- plugin-provided signals, such as harassment risk or recent incident reports

The plugin should deliver messages through a configured Discord destination, such as an admin channel ID, and should fail boot when enabled without required delivery configuration.

Core moderation should continue to record moderation reviews independently of whether notifications are enabled. The notification plugin may reference review commands or message/channel IDs, but it should not require raw message content unless a deployment explicitly enables content retention.

_Configuration_:
The plugin should be enabled explicitly with `PLUGINS=admin_notifications`.

Candidate settings:

- `ADMIN_NOTIFICATION_CHANNEL_ID`
- `ADMIN_NOTIFICATION_AMBIGUOUS_MIN_SCORE`
- `ADMIN_NOTIFICATION_AMBIGUOUS_MAX_SCORE`
- `ADMIN_NOTIFICATION_SHADOW_MODE=true|false`
- `ADMIN_NOTIFICATION_RATE_LIMIT_PER_MINUTE`

_Plugin integration_:
The first implementation should prefer existing hooks:

- `moderation_result` to inspect classifier scores
- `automod_outcome` to notify on automated moderation outcomes
- optional future plugin hooks or capabilities for domain-specific signals

If existing hooks are not enough, add a small typed notification event hook rather than making notification behavior part of the moderation strategies. The hook should carry moderator-safe references and derived metadata, not raw message content by default.

_Ambiguity policy_:
Ambiguity should be deterministic and configurable. For OpenAI moderation-style scores, an initial policy can treat a result as ambiguous when at least one category score falls within a configured review band and the message was not confidently handled by an existing strategy.

The policy should be implemented in application code, not delegated to another LLM call.

_Privacy and safety_:
Notifications should:

- include guild, channel, message, user mention, strategy, and score summary where safe
- avoid raw content unless `MODERATION_REVIEW_STORE_CONTENT=true` or a future explicit notification content setting allows it
- prefer links or IDs that let moderators inspect context in Discord
- rate-limit repeated alerts per guild/channel/user to avoid alert fatigue
- preserve administrator-only command and channel access assumptions

_Consequences_:

- Keeps admin notification optional and independently configurable
- Reuses existing moderation and plugin observation hooks
- Gives shadow mode and ambiguous decisions a clearer human-review workflow
- Avoids turning notification into punishment or automatic escalation
- May require a dedicated notification hook if future plugins need richer typed events
- Requires careful rate limiting and privacy defaults
