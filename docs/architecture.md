# Architecture

This document gives a quick map of the main runtime pieces in ModerationGPT and how they fit together.

## Runtime Flow

At startup, [bot.rb](../bot.rb) does five main things:

1. Validates environment configuration.
2. Builds the plugin registry from `PLUGIN_REQUIRES` and `PLUGINS`.
3. Boots enabled plugins.
4. Creates the Discord bot and shared application object.
5. Wires moderation strategies, admin commands, and ready handlers.

The shared application object lives in [lib/application.rb](../lib/application.rb). It mixes together:

- [Backend](../lib/backend.rb) for Redis-backed state
- [OpenAI](../lib/open_ai.rb) for moderation and rewrite calls

This keeps the rest of the bot working with a single `app` dependency.

## Message Handling

Incoming Discord messages flow through [bot.rb](../bot.rb) like this:

1. Ignore bot-authored messages.
2. Notify enabled plugins through the `message` hook.
3. Log a privacy-safe message receipt entry using anonymized user IDs.
4. If the message matches the admin command surface, dispatch to [lib/discord/moderation_command.rb](../lib/discord/moderation_command.rb).
5. Otherwise, hand the event to [lib/moderation/message_router.rb](../lib/moderation/message_router.rb).

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

[lib/backend.rb](../lib/backend.rb) stores application state in Redis. The key definitions live in [lib/data_model/keys.rb](../lib/data_model/keys.rb), and karma audit entries are represented by [lib/data_model/karma_event.rb](../lib/data_model/karma_event.rb).

Persisted state includes:

- known Discord servers
- per-server watchlists
- per-server user karma scores
- capped per-user karma history

See [docs/data-model.md](./data-model.md) for the exact Redis structures and field definitions.

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

- [TelemetryPlugin](../lib/plugins/telemetry_plugin.rb)
- [PersonalityPlugin](../lib/plugins/personality_plugin.rb)

## Privacy Boundary

The project treats Discord identifiers and message content carefully:

- user IDs are anonymized with [lib/telemetry/anonymizer.rb](../lib/telemetry/anonymizer.rb)
- logs avoid raw message content
- logs are emitted as structured events by [lib/logging.rb](../lib/logging.rb)
- OpenTelemetry is optional

That means the privacy boundary is part of the core architecture, not just an observability add-on.
