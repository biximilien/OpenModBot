# Architecture

This document gives a quick map of the main runtime pieces in OpenModBot and how they fit together.

## Runtime Flow

At startup, [bot.rb](../bot.rb) does five main things:

1. Validates environment configuration.
2. Creates the Discord bot and shared application object.
3. Builds the plugin registry from `PLUGIN_REQUIRES` and `PLUGINS`.
4. Boots enabled plugins.
5. Wires moderation strategies, admin commands, and ready handlers.

The shared application object lives in [lib/application.rb](../lib/application.rb). It mixes together:

- [Backend](../lib/backend.rb) for the core moderation store interface

It also delegates AI calls to a replaceable provider. OpenAI is the default provider and can be configured explicitly through [OpenAIPlugin](../lib/plugins/open_ai_plugin.rb). [GoogleAIPlugin](../lib/plugins/google_ai_plugin.rb) can replace it with a Gemini-backed provider during `boot`, and external AI backend plugins can follow the same provider interface.

This keeps the rest of the bot working with a single `app` dependency.

The application defaults to an in-memory moderation store so the bot can run without database plugins. [RedisPlugin](../lib/plugins/redis_plugin.rb) can replace it with Redis-backed moderation storage, and [PostgresPlugin](../lib/plugins/postgres_plugin.rb) can replace it with Postgres-backed moderation storage while also exposing the `postgres_connection` capability to other plugins.

## Message Handling

Incoming Discord messages flow through [bot.rb](../bot.rb) like this:

1. Ignore bot-authored messages.
2. Notify enabled plugins through the `message` hook.
3. Enabled plugins can observe or capture the event, such as the harassment plugin's passive interaction ingestion.
4. Log a privacy-safe message receipt entry using anonymized user IDs.
5. If the message matches the admin command surface, dispatch to [lib/discord/moderation_command.rb](../lib/discord/moderation_command.rb).
6. Otherwise, hand the event to [lib/moderation/message_router.rb](../lib/moderation/message_router.rb).

`MessageRouter` walks the configured strategies in order and executes the first strategy whose `condition(event)` returns true.

`ModerationCommand` owns the built-in admin command dispatch and can also dispatch plugin-provided admin command objects contributed through the plugin registry. Parsing plus watchlist and karma handlers live in separate classes under [lib/discord](../lib/discord).

## Moderation Pipeline

The moderation pipeline is organized around a base strategy in [lib/moderation/strategy.rb](../lib/moderation/strategy.rb) plus concrete strategy classes in [lib/moderation/strategies](../lib/moderation/strategies).

Built-in strategy order is:

1. [WatchListStrategy](../lib/moderation/strategies/watch_list_strategy.rb)
2. [RemoveMessageStrategy](../lib/moderation/strategies/remove_message_strategy.rb)
3. Any plugin-provided moderation strategies

The base strategy is responsible for shared behavior:

- fetching and caching AI moderation results on the Discord event
- recording live and shadow-mode moderation review entries
- recording plugin hook notifications for moderation outcomes
- decrementing user karma for infractions
- checking whether an automod threshold was crossed
- recording automod outcomes in karma history

This means the concrete strategies mostly answer two questions:

- should this strategy handle the event?
- what should happen when it does?

## AI Provider Integration

[lib/open_ai.rb](../lib/open_ai.rb) implements the default AI provider and wraps the two OpenAI calls used by the bot:

- `/v1/moderations` for message classification
- `/v1/responses` for watchlist rewrites

[lib/google_ai.rb](../lib/google_ai.rb) implements the optional Google AI provider. It uses Gemini `generateContent` for moderation, watchlist rewrites, and structured harassment classifier calls.

Providers return a small `ModerationResult` value object for moderation calls and a plain rewritten string for rewrites.

AI provider requests are wrapped in `Telemetry.in_span(...)`, but telemetry exporting is still optional. When the telemetry plugin is disabled, the tracing path becomes a no-op and the rest of the bot continues to work normally.

AI providers expose the same application-facing methods: `moderate_text`, `moderation_rewrite`, `generate_structured`, `query`, and `response_text`. The harassment classifier uses `generate_structured` plus `response_text` for schema-bound classifier calls; moderation strategies use `moderate_text` and `moderation_rewrite`. `query` remains as a low-level compatibility method for provider-specific calls.

## Persistence Model

[lib/backend.rb](../lib/backend.rb) delegates core moderation state to the configured moderation store. Karma audit entries are represented by [lib/data_model/karma_event.rb](../lib/data_model/karma_event.rb), and review entries are represented by [lib/data_model/moderation_review_entry.rb](../lib/data_model/moderation_review_entry.rb).

Core moderation store implementations live under [lib/moderation/stores](../lib/moderation/stores):

- `InMemoryStore`, the default, for plugin-free local operation
- `RedisStore`, enabled by the `redis` plugin
- `PostgresStore`, enabled by the `postgres` plugin

All stores expose the same application-level methods for:

- known Discord servers
- per-server watchlists
- per-server user karma scores
- capped per-user karma history
- capped moderation review queues

The Postgres core moderation store currently creates its small schema at initialization time for local development and
simple deployments. Production deployments should still treat schema changes as an explicit operational step: run the
harassment SQL bootstrap/migration scripts intentionally, review core moderation table changes before rollout, and avoid
depending on process startup as the only migration mechanism.

See [docs/data-model.md](./data-model.md) for the structures and field definitions.

## Harassment Pipeline

The harassment pipeline is owned by the optional harassment plugin and composed from reusable domain runtime pieces.

Plugin-composed runtime pieces:

- [lib/plugins/harassment_plugin.rb](../lib/plugins/harassment_plugin.rb)
- [lib/harassment/runtime/runtime.rb](../lib/harassment/runtime/runtime.rb)
- [lib/harassment/runtime/worker_runner.rb](../lib/harassment/runtime/worker_runner.rb)
- [lib/harassment/interaction/message_ingestor.rb](../lib/harassment/interaction/message_ingestor.rb)
- [lib/harassment/classification/pipeline.rb](../lib/harassment/classification/pipeline.rb)
- [lib/harassment/classification/worker.rb](../lib/harassment/classification/worker.rb)
- [lib/harassment/interaction/context_assembler.rb](../lib/harassment/interaction/context_assembler.rb)
- backend-specific repositories under [lib/harassment/repositories](../lib/harassment/repositories)

Harassment service and query pieces:

- [lib/harassment/classification/service.rb](../lib/harassment/classification/service.rb)
- [lib/harassment/classifier/definition.rb](../lib/harassment/classifier/definition.rb)
- [lib/harassment/risk/read_model.rb](../lib/harassment/risk/read_model.rb)
- [lib/harassment/query_service.rb](../lib/harassment/query_service.rb)
- [lib/plugins/harassment_command.rb](../lib/plugins/harassment_command.rb)

The harassment domain is grouped by responsibility under [lib/harassment](../lib/harassment):

- `classification/` for classification jobs, records, pipeline, worker, status, and classification service
- `classifier/` for classifier identity and provider-backed/cached classifier implementations
- `incident/` for incident values, collections, queries, and incident reports
- `interaction/` for captured Discord interaction events, context assembly, ingestion, and retention
- `relationship/` for relationship edges, rebuilds, and pair reports
- `risk/` for scoring, decay, read-model projections, and risk reports
- `persistence/` for repository factory and Postgres migration/verification helpers

New code should require harassment-domain files from these grouped paths directly.

The harassment plugin builds a runtime that stores immutable interaction events, enqueues classification jobs keyed by `server_id`, `message_id`, and `classifier_version`, assembles bounded transient context, wraps classifier calls with cache and per-server rate-limit enforcement, and processes due jobs asynchronously on a background thread. The harassment classification service provides the classifier version and the harassment-specific prompt/schema definition used by [lib/harassment/classifier/structured_classifier.rb](../lib/harassment/classifier/structured_classifier.rb). Successful classification records are then handed to the classification service, which updates its idempotent read model. The query service exposes moderator-facing reports from that read model and, when configured, durable incident repositories.

Classifier cache keys are derived from server scope, classifier version, classifier prompt/schema identity, and normalized message/context input. When a server exceeds the configured classifier call budget, the runtime defers the job forward without consuming a retry attempt.

The harassment plugin requires the `postgres` plugin. Its runtime uses the shared Postgres plugin connection with Postgres-backed repositories for interaction events, classification records, classification jobs, classifier cache entries, per-server rate-limit buckets, and relationship-edge projections. The Redis bootstrap path remains available for older deployments that are migrating historical harassment data; cache/rate-limit state resets on cutover, while relationship-edge projections can be rebuilt from stored classified events and their latest stored classification records.

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

- lifecycle hooks: `boot`, `ready`, `shutdown`, `message`
- moderation observation hooks: `moderation_result`, `infraction`, `automod_outcome`
- behavior hooks: `rewrite_instructions`, `moderation_strategies`
- command contribution hook: `commands`
- optional infrastructure capabilities through `capabilities` and `PluginRegistry#capability`

The `boot` hook receives the shared runtime context: `app:`, `bot:`, and `plugin_registry:`. Plugins should require only the keyword arguments they need. For example, infrastructure plugins usually need `app:` or `plugin_registry:`, while delivery-oriented plugins may need `bot:` to interact with Discord outside a single message event.

Plugins that provide shared optional infrastructure should expose it as a named capability, such as `postgres_connection` or `ai_provider`. Domain plugins should consume those capabilities through the registry instead of depending directly on a concrete infrastructure plugin class. Existing named registry helpers may remain as compatibility shims for common capabilities.

The public Ruby namespace is `OpenModBot`.

Current built-in plugins:

- [HarassmentPlugin](../lib/plugins/harassment_plugin.rb)
- [AdminNotificationsPlugin](../lib/plugins/admin_notifications_plugin.rb)
- [GoogleAIPlugin](../lib/plugins/google_ai_plugin.rb)
- [OpenAIPlugin](../lib/plugins/open_ai_plugin.rb)
- [PostgresPlugin](../lib/plugins/postgres_plugin.rb)
- [RedisPlugin](../lib/plugins/redis_plugin.rb)
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
