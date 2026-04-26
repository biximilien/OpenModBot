# Architecture

This document gives a quick map of the main runtime pieces in ModerationGPT and how they fit together.

## Runtime Flow

At startup, [bot.rb](../bot.rb) does six main things:

1. Validates environment configuration.
2. Builds the plugin registry from `PLUGIN_REQUIRES` and `PLUGINS`.
3. Boots enabled plugins.
4. Creates the Discord bot and shared application object.
5. Creates the harassment runtime when the harassment plugin is enabled.
6. Wires moderation strategies, admin commands, and ready handlers.

The shared application object lives in [lib/application.rb](../lib/application.rb). It mixes together:

- [Backend](../lib/backend.rb) for Redis-backed state
- [OpenAI](../lib/open_ai.rb) for moderation and rewrite calls

This keeps the rest of the bot working with a single `app` dependency.

## Message Handling

Incoming Discord messages flow through [bot.rb](../bot.rb) like this:

1. Ignore bot-authored messages.
2. If enabled, hand the Discord event to the platform-owned harassment runtime for passive interaction ingestion.
3. Notify enabled plugins through the `message` hook.
4. Log a privacy-safe message receipt entry using anonymized user IDs.
5. If the message matches the admin command surface, dispatch to [lib/discord/moderation_command.rb](../lib/discord/moderation_command.rb).
6. Otherwise, hand the event to [lib/moderation/message_router.rb](../lib/moderation/message_router.rb).

`MessageRouter` walks the configured strategies in order and executes the first strategy whose `condition(event)` returns true.

`ModerationCommand` owns the built-in admin commands and can also dispatch plugin-provided admin command objects contributed through the plugin registry.

## Moderation Pipeline

The moderation pipeline is organized around a base strategy in [lib/moderation/strategy.rb](../lib/moderation/strategy.rb) plus concrete strategy classes in [lib/moderation/strategies](../lib/moderation/strategies).

Built-in strategy order is:

1. [WatchListStrategy](../lib/moderation/strategies/watch_list_strategy.rb)
2. [RemoveMessageStrategy](../lib/moderation/strategies/remove_message_strategy.rb)
3. Any plugin-provided moderation strategies

The base strategy is responsible for shared behavior:

- fetching and caching OpenAI moderation results on the Discord event
- recording plugin hook notifications for moderation outcomes
- decrementing user karma for infractions
- checking whether an automod threshold was crossed
- recording automod outcomes in karma history

This means the concrete strategies mostly answer two questions:

- should this strategy handle the event?
- what should happen when it does?

## OpenAI Integration

[lib/open_ai.rb](../lib/open_ai.rb) wraps the two OpenAI calls used by the bot:

- `/v1/moderations` for message classification
- `/v1/responses` for watchlist rewrites

The module returns a small `ModerationResult` value object for moderation calls and a plain rewritten string for rewrites.

OpenAI requests are wrapped in `Telemetry.in_span(...)`, but telemetry exporting is still optional. When the telemetry plugin is disabled, the tracing path becomes a no-op and the rest of the bot continues to work normally.

## Persistence Model

[lib/backend.rb](../lib/backend.rb) stores the original moderation state in Redis. The key definitions live in [lib/data_model/keys.rb](../lib/data_model/keys.rb), and karma audit entries are represented by [lib/data_model/karma_event.rb](../lib/data_model/karma_event.rb).

Redis-backed state includes:

- known Discord servers
- per-server watchlists
- per-server user karma scores
- capped per-user karma history
See [docs/data-model.md](./data-model.md) for the exact Redis structures and field definitions.

## Harassment Pipeline

The harassment pipeline is split between a platform runtime and a plugin-owned read model.

Platform-owned runtime pieces:

- [lib/harassment/runtime.rb](../lib/harassment/runtime.rb)
- [lib/harassment/message_ingestor.rb](../lib/harassment/message_ingestor.rb)
- [lib/harassment/classification_pipeline.rb](../lib/harassment/classification_pipeline.rb)
- [lib/harassment/classification_worker.rb](../lib/harassment/classification_worker.rb)
- [lib/harassment/context_assembler.rb](../lib/harassment/context_assembler.rb)
- backend-specific repositories under [lib/harassment/repositories](../lib/harassment/repositories)

Plugin-owned pieces:

- [lib/plugins/harassment_plugin.rb](../lib/plugins/harassment_plugin.rb)
- [lib/harassment/read_model.rb](../lib/harassment/read_model.rb)
- [lib/harassment/query_service.rb](../lib/harassment/query_service.rb)
- [lib/plugins/harassment_command.rb](../lib/plugins/harassment_command.rb)

The current runtime stores immutable interaction events, enqueues classification jobs keyed by `message_id` and `classifier_version`, assembles bounded transient context, wraps classifier calls with cache and per-server rate-limit enforcement, and processes due jobs asynchronously on a background thread. The harassment plugin provides the classifier version and the harassment-specific prompt/schema definition used by [lib/harassment/open_ai_classifier.rb](../lib/harassment/open_ai_classifier.rb). Successful classification records are then handed to the harassment plugin, which updates its idempotent read model and exposes moderator-facing queries.

Classifier cache keys are derived from server scope, classifier version, classifier prompt/schema identity, and normalized message/context input. When a server exceeds the configured classifier call budget, the runtime defers the job forward without consuming a retry attempt.

When `HARASSMENT_STORAGE_BACKEND=postgres` is enabled, the runtime uses Postgres-backed repositories for interaction events, classification records, classification jobs, classifier cache entries, per-server rate-limit buckets, and relationship-edge projections. The Redis bootstrap path migrates the durable interaction, classification, and job records; cache/rate-limit state resets on cutover, while relationship-edge projections can be rebuilt from stored classified events and their latest stored classification records.

The moderator-facing incident and risk surface no longer depends only on process-local incident memory when durable repositories are available. The harassment query layer can reconstruct incidents from stored classified interaction events plus stored classification records, which keeps `recent incidents` and incident-derived risk signals meaningful across restarts.

The harassment plugin is passive-only: it does not punish users automatically. Its operator surface currently lives in Discord through:

- `!moderation harassment risk @user`
- `!moderation harassment pair @user_a @user_b`
- `!moderation harassment incidents [@user] [1h|24h|7d] [limit]`

## Automoderation

[lib/moderation/automod_policy.rb](../lib/moderation/automod_policy.rb) applies the configured automatic moderation action once a user crosses the configured karma threshold.

Supported actions:

- `log_only`
- `timeout`
- `kick`
- `ban`

Outcome names are centralized in [lib/moderation/automod_outcome.rb](../lib/moderation/automod_outcome.rb). Those values are reused in logs, tests, and karma history so automated behavior has a stable audit trail.

## Plugin System

The plugin system is defined by:

- [lib/plugin.rb](../lib/plugin.rb)
- [lib/plugin_registry.rb](../lib/plugin_registry.rb)

Plugins can be:

- built in and registered in code
- loaded from external packages through `PLUGIN_REQUIRES`
- enabled through `PLUGINS`

Current hook types include:

- lifecycle hooks: `boot`, `ready`, `message`
- moderation observation hooks: `moderation_result`, `infraction`, `automod_outcome`
- behavior hooks: `rewrite_instructions`, `moderation_strategies`
- command contribution hook: `commands`

Current built-in plugins:

- [HarassmentPlugin](../lib/plugins/harassment_plugin.rb)
- [TelemetryPlugin](../lib/plugins/telemetry_plugin.rb)
- [PersonalityPlugin](../lib/plugins/personality_plugin.rb)

## Privacy Boundary

The project treats Discord identifiers and message content carefully:

- user IDs are anonymized with [lib/telemetry/anonymizer.rb](../lib/telemetry/anonymizer.rb)
- logs avoid raw message content
- logs are emitted as structured events by [lib/logging.rb](../lib/logging.rb)
- harassment classifier payloads use pseudonymous participant labels and transiently assembled context
- OpenTelemetry is optional

That means the privacy boundary is part of the core architecture, not just an observability add-on.
