# ADR-025: Use Optional Infrastructure Plugins for Shared Services

_Status_: Accepted

_Context_:
Some capabilities are useful to multiple plugins but should not become mandatory dependencies of the core application. Postgres, AI providers, telemetry exporters, and future worker infrastructure are examples of shared infrastructure that may be absent or replaced in different deployments.

At the same time, domain plugins need a clear way to consume these capabilities without creating hidden globals, hard boot-time dependencies, or duplicated connection setup.

_Decision_:
Shared infrastructure that is optional at deployment time should be exposed through plugins.

Infrastructure plugins:

- own setup for the external service they represent
- validate their own required configuration during `boot`
- expose small public accessors through the plugin registry for other plugins or platform runtime code
- are discovered through the plugin registry
- are enabled explicitly through environment configuration

Domain plugins and runtime components must consume optional infrastructure through composition. They should not create global clients for optional services directly when an infrastructure plugin already owns that concern.

The shared application object may continue to own always-on core dependencies, such as the Redis-backed moderation state used by the base bot. Optional infrastructure, such as Postgres, should stay outside the shared application object unless it becomes a required core dependency.

_Current application_:

- `PostgresPlugin` owns `DATABASE_URL` and exposes the database connection through `PluginRegistry#postgres_connection`.
- `OpenAIPlugin` exposes the default AI provider for moderation, rewrites, and structured classifier calls.
- `GoogleAIPlugin` exposes an optional Gemini-backed AI provider with the same application-facing provider interface.
- `TelemetryPlugin` owns OpenTelemetry setup.
- `HarassmentPlugin` owns its runtime and background worker lifecycle, and obtains Postgres-backed repositories through plugin composition when `HARASSMENT_STORAGE_BACKEND=postgres`.
- The base application still owns Redis-backed moderation state and delegates AI helper methods to the configured provider.

_Boot behavior_:

Plugin `boot` is a configuration boundary. Boot failures should fail fast so the bot does not continue with partially initialized required infrastructure. Runtime hooks such as `message`, `ready`, moderation observations, command contribution, and strategy contribution may remain isolated so one plugin hook failure does not stop unrelated processing.

_Consequences_:

- Keeps optional services optional without obscuring dependencies
- Makes plugin-to-plugin infrastructure usage explicit
- Allows lightweight deployments to avoid unnecessary gems and services
- Gives production deployments a clear place to configure shared infrastructure
- Requires careful boot ordering and clear error messages when a domain plugin depends on an infrastructure plugin that is not enabled
