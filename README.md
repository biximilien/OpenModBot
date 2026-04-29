# ModerationGPT

ModerationGPT is a Discord moderation bot for text channels. By default it uses OpenAI's moderation endpoint to classify messages, in-memory moderation state, and the OpenAI Responses API to rewrite flagged messages from watched users in a more constructive tone. Optional plugins add Redis or Postgres-backed durable moderation state, passive harassment analysis, OpenTelemetry, rewrite personalities, and replaceable AI providers.

## Features

Core moderation:

- Deletes AI-flagged messages.
- Rewrites flagged messages from watched users in a more constructive tone.
- Tracks per-server watchlists, karma scores, and capped karma audit history.
- Records a capped per-server moderation review queue for recent live and shadow-mode actions.
- Supports shadow mode with `MODERATION_SHADOW_MODE=true` to review would-be actions without deleting messages, reposting rewrites, changing karma, or applying automod.
- Applies optional automod actions when karma crosses `KARMA_AUTOMOD_THRESHOLD`: `log_only`, `timeout`, `kick`, or `ban`.
- Skips punitive automod actions for members with elevated moderation permissions.

AI providers:

- Uses OpenAI by default.
- Supports Google AI/Gemini with `PLUGINS=google_ai`.
- Supports structured classifier output for harassment analysis through the shared AI provider interface.

Optional plugins:

- `harassment` passively captures interaction events, classifies harassment risk asynchronously, and exposes moderator insight commands without automated punishment.
- `redis` stores core moderation state in Redis.
- `postgres` stores core moderation state in Postgres and provides the required durable storage dependency for harassment.
- `personality` changes the rewrite tone for moderated watchlist messages.
- `telemetry` enables OpenTelemetry exporting while keeping identifier anonymization in place.

Plugin capabilities:

- External plugins can observe messages, moderation results, infractions, and automod outcomes.
- Plugins can contribute rewrite instructions, moderation strategies, admin commands, and AI providers.

## How It Works

The bot listens for Discord messages and applies two moderation paths:

- Watched users: flagged messages are deleted and replaced with a rewritten version.
- Other users: flagged messages are deleted.

Administrators can manage moderation state with:

```bash
!moderation help
!moderation watchlist
!moderation watchlist add @user
!moderation watchlist remove @user
!moderation karma @user
!moderation karma history @user
!moderation karma history @user 10
!moderation karma set @user -3
!moderation karma reset @user
!moderation karma add @user 1
!moderation karma remove @user 1
!moderation review recent
!moderation review recent 10
!moderation review @user
!moderation review clear
!moderation review repost 1234567890
!moderation harassment risk @user
!moderation harassment pair @user_a @user_b
!moderation harassment incidents 3
!moderation harassment incidents @user 3
!moderation harassment incidents 24h 3
!moderation harassment incidents @user 24h 3
```

Each moderated infraction decreases the user's per-server karma score and records a capped audit history for that user. When a score crosses `KARMA_AUTOMOD_THRESHOLD`, the bot applies `KARMA_AUTOMOD_ACTION` and records the outcome in karma history; users who are already below the threshold do not receive repeated automated actions for every additional infraction. Supported actions are `log_only`, `timeout`, `kick`, and `ban`; the default is `timeout`. Timeout requires the Discord moderate-members permission, which is included in the generated invite URL. If you configure `kick` or `ban`, grant the bot the matching Discord permission in that server. The bot skips punitive automated actions for members with elevated moderation permissions.

Set `MODERATION_SHADOW_MODE=true` to classify messages and record the review queue without deleting messages, reposting rewrites, changing karma, or applying automod. Shadow mode generates would-be rewrites by default; set `MODERATION_SHADOW_REWRITE=false` to avoid rewrite-generation calls while testing. Moderators can inspect the queue with `!moderation review recent [limit]`, filter with `!moderation review @user [limit]`, and clear it with `!moderation review clear`.

Review reposting is privacy-gated. By default, review entries do not store original message content and `!moderation review repost message_id` reports that content is unavailable. Set `MODERATION_REVIEW_STORE_CONTENT=true` to store original flagged content in Redis review entries and allow moderators to repost it with the repost command. `restore` remains accepted as a compatibility alias.

## Requirements

- Ruby 3.3.11, matching `.tool-versions` and `Gemfile`
- Bundler 2.4.5 or newer
- Discord bot token
- OpenAI API key, or a Google AI API key when using the `google_ai` provider plugin

This repository is intended to work on Linux, macOS, and Windows. The examples below use a POSIX-style shell for brevity; when using PowerShell or `cmd.exe`, keep the same values but use your shell's syntax for file copying and environment variable editing.

## Configuration

Create a `.env` file in the project root. The simplest approach is to copy `.env.sample` and fill in your secrets:

```bash
OPENAI_API_KEY=my_openai_secret
GOOGLE_AI_API_KEY=my_google_ai_secret
DISCORD_BOT_TOKEN=my_discord_secret
REDIS_URL=redis://localhost:6379/0
DATABASE_URL=postgres://postgres:postgres@localhost:5432/moderationgpt
OPENAI_MODERATION_MODEL=omni-moderation-latest
OPENAI_REWRITE_MODEL=gpt-4.1-mini
GOOGLE_AI_MODEL=gemini-2.5-flash
HARASSMENT_CLASSIFIER_MODEL=gpt-4o-2024-08-06
HARASSMENT_CLASSIFIER_CACHE_TTL_SECONDS=3600
HARASSMENT_CLASSIFIER_RATE_LIMIT_PER_MINUTE=30
MODERATION_SHADOW_MODE=false
MODERATION_SHADOW_REWRITE=true
MODERATION_REVIEW_STORE_CONTENT=false
KARMA_AUTOMOD_THRESHOLD=-5
KARMA_AUTOMOD_ACTION=timeout
KARMA_TIMEOUT_SECONDS=3600
LOG_INVITE_URL=false
LOG_FORMAT=json
TELEMETRY_HASH_SALT=replace_with_random_secret
PLUGIN_REQUIRES=
PLUGINS=
PERSONALITY=objective
```

`REDIS_URL`, `DATABASE_URL`, `OPENAI_MODERATION_MODEL`, `OPENAI_REWRITE_MODEL`, `GOOGLE_AI_MODEL`, `HARASSMENT_CLASSIFIER_MODEL`, `HARASSMENT_CLASSIFIER_CACHE_TTL_SECONDS`, `HARASSMENT_CLASSIFIER_RATE_LIMIT_PER_MINUTE`, `MODERATION_SHADOW_MODE`, `MODERATION_SHADOW_REWRITE`, `MODERATION_REVIEW_STORE_CONTENT`, `KARMA_AUTOMOD_THRESHOLD`, `KARMA_AUTOMOD_ACTION`, `KARMA_TIMEOUT_SECONDS`, `LOG_INVITE_URL`, and `LOG_FORMAT` are optional. `REDIS_URL` is only used when the `redis` plugin is enabled. `DATABASE_URL` is only used when the `postgres` plugin is enabled. `TELEMETRY_HASH_SALT` is used to anonymize Discord identifiers in logs and traces; set it to a stable random secret for your deployment.

## Local Development

Install dependencies:

```bash
gem install bundler -v 2.4.5
bundle install
```

Enable optional Postgres dependencies when using the Postgres plugin:

```bash
bundle config set --local with postgres
bundle install
```

Start Redis if you want Redis-backed core moderation state:

```bash
docker compose up redis
```

If you are not using Docker, point `REDIS_URL` at any reachable Redis instance and run with `PLUGINS=redis`. With no database plugin enabled, moderation state is in-memory and resets on restart.

Run the bot:

```bash
bundle exec ruby bot.rb
```

Run tests:

```bash
bundle exec rspec
```

Run lint:

```bash
bundle exec rubocop
```

The default specs stub AI providers and optional databases, so they do not require external API calls.

The moderation data model is documented in `docs/data-model.md`.
The application structure is documented in `docs/architecture.md`.
Architecture decisions are tracked in `docs/adrs/README.md`.

## Logging

The bot emits structured logs by default using JSON lines. Each entry includes a timestamp, level, event name, and any event-specific fields.

Use `LOG_FORMAT=plain` if you want a more human-oriented log format during local development.

## Operations

Enabled plugins are booted during startup. Boot failures are intentional hard failures because they usually mean required configuration or infrastructure is missing, such as enabling `postgres` without a usable `DATABASE_URL`.

Runtime plugin hooks are isolated after boot. If a hook fails while handling messages or contributing optional behavior, the bot logs `plugin_hook_failed` and continues processing unrelated work.

The harassment background worker logs `harassment_worker_failed` when one processing pass fails, then continues polling due jobs. Repeated worker failures usually indicate an unhealthy classifier, repository, or database dependency and should be treated as operational alerts.

## Plugins

Optional built-in plugins can be enabled with `PLUGINS`, using comma-separated names:

```bash
PLUGINS=telemetry
```

Built-in plugins:

- `harassment`
- `google_ai`
- `openai`
- `postgres`
- `redis`
- `telemetry`
- `personality`

Plugin `boot` is a configuration boundary: if an enabled plugin cannot initialize required infrastructure, startup fails instead of continuing with a partially configured bot. Runtime hooks such as `message`, moderation observations, strategy contribution, and command contribution remain isolated so one plugin hook failure does not stop unrelated processing.

Optional infrastructure is exposed through plugins rather than hidden globals. For example, the `redis` plugin owns `REDIS_URL` and exposes Redis-backed moderation storage, while the `postgres` plugin owns `DATABASE_URL` and exposes both Postgres-backed moderation storage and the database connection used by harassment.

Core moderation storage options:

- no database plugin: in-memory watchlists, karma, and review queue; useful for local trials and tests
- `PLUGINS=redis`: Redis-backed watchlists, karma, and review queue
- `PLUGINS=postgres`: Postgres-backed watchlists, karma, and review queue

The shared application delegates AI calls through a replaceable provider. OpenAI is the default provider, and enabling `PLUGINS=openai` configures it explicitly through the plugin system. Enable `PLUGINS=google_ai` and set `GOOGLE_AI_API_KEY` to use Gemini through Google AI instead:

```bash
PLUGINS=google_ai
GOOGLE_AI_API_KEY=my_google_ai_secret
GOOGLE_AI_MODEL=gemini-2.5-flash
```

AI provider configuration:

| Provider | Plugin | Required key | Model settings | Default classifier model |
| --- | --- | --- | --- | --- |
| OpenAI | `openai` or default | `OPENAI_API_KEY` | `OPENAI_MODERATION_MODEL`, `OPENAI_REWRITE_MODEL`, `HARASSMENT_CLASSIFIER_MODEL` | `gpt-4o-2024-08-06` |
| Google AI | `google_ai` | `GOOGLE_AI_API_KEY` | `GOOGLE_AI_MODEL`, `HARASSMENT_CLASSIFIER_MODEL` | `GOOGLE_AI_MODEL` |

External AI backend plugins can provide the same provider methods (`moderate_text`, `moderation_rewrite`, `generate_structured`, `query`, and `response_text`) and assign that provider during `boot`.

When the `harassment` plugin is enabled with `postgres`, the bot passively captures interaction events, enqueues harassment classification work, and records classified incidents in a harassment read model without applying automated enforcement.

The harassment plugin owns its runtime: Discord message ingestion, backend-owned event and job storage, transient context assembly, classifier-output caching, per-server rate limiting, and background classification processing. It composes the harassment classification service, query service, read model, worker lifecycle, and Discord command output without applying automated enforcement.

The harassment plugin always uses Postgres-backed repositories for interaction events, classification records, classification jobs, classifier cache entries, per-server rate-limit buckets, and persisted relationship-edge projections. Enable the shared database capability with the `postgres` plugin:

```bash
PLUGINS=postgres,harassment
```

To bootstrap the current Redis harassment state into Postgres before cutover, run:

```bash
PLUGINS=redis,postgres
ruby scripts/bootstrap_harassment_postgres.rb
```

With Docker Compose, use:

```bash
BUNDLE_WITH=postgres PLUGINS=redis,postgres docker compose --profile postgres run --rm bot ruby scripts/bootstrap_harassment_postgres.rb
```

This script is idempotent for already-migrated interaction events, classification records, and classification jobs.

Classifier cache entries and per-server rate-limit buckets are operational state and are not bootstrapped. They start fresh on cutover. Relationship-edge projections are rebuilt separately from stored classified interaction events and classification records.

To rebuild relationship-edge projections from stored harassment interaction events and classification records, run:

```bash
PLUGINS=postgres
ruby scripts/rebuild_harassment_relationship_edges.rb
```

With Docker Compose, use:

```bash
BUNDLE_WITH=postgres PLUGINS=postgres docker compose --profile postgres run --rm bot ruby scripts/rebuild_harassment_relationship_edges.rb
```

You can scope the rebuild to a specific server:

```bash
PLUGINS=postgres
ruby scripts/rebuild_harassment_relationship_edges.rb 123456789012345678
```

When the harassment plugin boots against durable repositories, moderator-facing `risk` and `recent incidents` queries are reconstructed from stored interaction events and classification records rather than relying only on process-local incident memory.

The harassment implementation is organized by domain under `lib/harassment`, with grouped folders for `classification`, `classifier`, `discord`, `incident`, `interaction`, `relationship`, `risk`, `runtime`, `repositories`, and `persistence`. New code should require files from those grouped paths directly.

To compare Redis and Postgres harassment counts, inspect Postgres relationship-edge totals, and run a small set of sampled row checks before cutover, run:

```bash
PLUGINS=redis,postgres
ruby scripts/verify_harassment_postgres.rb
```

With Docker Compose, use:

```bash
BUNDLE_WITH=postgres PLUGINS=redis,postgres docker compose --profile postgres run --rm bot ruby scripts/verify_harassment_postgres.rb
```

To verify specific known message IDs as part of the cutover check, pass them as arguments:

```bash
PLUGINS=redis,postgres
ruby scripts/verify_harassment_postgres.rb 123456789012345678 234567890123456789
```

The cutover sequence is documented in `docs/harassment-postgres-cutover.md`.

Classifier context is assembled transiently from retained interaction events and sent to the configured AI provider with pseudonymous participant labels rather than raw Discord IDs. `HARASSMENT_CLASSIFIER_MODEL` defaults to `GOOGLE_AI_MODEL` when `google_ai` is the configured provider, otherwise it defaults to the OpenAI classifier model.

Harassment classifications are cached by server, classifier version, prompt/schema identity, and normalized message/context input for `HARASSMENT_CLASSIFIER_CACHE_TTL_SECONDS`. Outbound harassment classification calls are also paced per server with `HARASSMENT_CLASSIFIER_RATE_LIMIT_PER_MINUTE`; deferred jobs are rescheduled without consuming retry attempts.

When the `harassment` plugin is enabled, moderators can inspect the derived signals directly from Discord with:

```bash
!moderation harassment risk @user
!moderation harassment pair @user_a @user_b
!moderation harassment incidents 3
!moderation harassment incidents @user 3
!moderation harassment incidents 24h 3
!moderation harassment incidents @user 24h 3
```

The incidents command supports fixed time windows of `1h`, `24h`, and `7d`. The optional mention, limit, and window tokens can appear in flexible order as long as each is present at most once.

External plugin packages can follow the same `ModerationGPT::Plugin` hook interface and register with `ModerationGPT::PluginRegistry.register`. Use `PLUGIN_REQUIRES` to load plugin packages before `PLUGINS` is resolved:

```bash
PLUGIN_REQUIRES=moderation_gpt/plugins/audit_webhook
PLUGINS=audit_webhook
```

Plugin hooks:

- `boot`
- `ready`
- `message`
- `moderation_result`
- `infraction`
- `automod_outcome`
- `rewrite_instructions`
- `moderation_strategies`
- `commands`

Plugin command objects should respond to:

- `matches?(event)` to decide whether the command should handle a `!moderation ...` message
- `handle(event)` to respond to the matched command
- optional `help_lines` to add command usage lines to `!moderation help`

## Personalities

The personality plugin controls the tone used when the bot rewrites moderated watchlist messages:

```bash
PLUGINS=personality
PERSONALITY=objective
```

Available personalities are `objective`, `empathetic`, `teacher`, `supportive`, `formal`, `concise`, `diplomatic`, `coach`, `plainspoken`, `legalistic`, `community_manager`, `southern_charm`, `shakespearean`, `robot`, `zen`, `pirate`, and `poetic`. The default is `objective`, which uses a direct, neutral rewrite style.

## Docker

Run the bot with the Compose services:

```bash
docker compose up --build
```

The bot service reads secrets from `.env`. Inside Compose, `REDIS_URL` is set to `redis://redis:6379/0`; it is used when `PLUGINS` includes `redis`. Redis uses append-only persistence with `appendfsync everysec`, and stores local state in `./redis-data`.

To run with harassment, build the image with the `postgres` bundle group and enable the Compose Postgres profile:

```bash
BUNDLE_WITH=postgres PLUGINS=postgres,harassment docker compose --profile postgres up --build
```

Compose starts a local `postgres` service, initializes the harassment schema from `db/harassment/001_initial_schema.sql`, and points the bot at `postgres://postgres:postgres@postgres:5432/moderationgpt` unless `DATABASE_URL` is overridden.

## OpenTelemetry

Optional OpenTelemetry settings can be added to `.env`:

```bash
PLUGINS=telemetry
TELEMETRY_ENABLED=true
OTEL_EXPORTER_OTLP_ENDPOINT=https://api.honeycomb.io
OTEL_EXPORTER_OTLP_HEADERS=x-honeycomb-team=secretkey
OTEL_SERVICE_NAME=ModerationGPT
```

OpenTelemetry is disabled by default. Identifier anonymization still runs when telemetry is disabled. Enable the telemetry plugin explicitly with `PLUGINS=telemetry`, then set `TELEMETRY_ENABLED=true` to turn on OpenTelemetry inside that plugin. Install optional telemetry dependencies with `bundle config set --local with telemetry` before `bundle install` when enabling OpenTelemetry locally. For Docker, build with `BUNDLE_WITH=telemetry docker compose build`. When combining optional groups in Docker, use `BUNDLE_WITH=postgres:telemetry`.
