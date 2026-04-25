# ModerationGPT

ModerationGPT is a Discord moderation bot for text channels. It uses OpenAI's moderation endpoint to classify messages, Redis to store per-server watchlists, and the OpenAI Responses API to rewrite flagged messages from watched users in a more constructive tone.

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
!moderation harassment risk @user
!moderation harassment pair @user_a @user_b
!moderation harassment incidents 3
```

Each moderated infraction decreases the user's per-server karma score and records a capped audit history for that user. When a score crosses `KARMA_AUTOMOD_THRESHOLD`, the bot applies `KARMA_AUTOMOD_ACTION` and records the outcome in karma history; users who are already below the threshold do not receive repeated automated actions for every additional infraction. Supported actions are `log_only`, `timeout`, `kick`, and `ban`; the default is `timeout`. Timeout requires the Discord moderate-members permission, which is included in the generated invite URL. If you configure `kick` or `ban`, grant the bot the matching Discord permission in that server. The bot skips punitive automated actions for members with elevated moderation permissions.

## Requirements

- Ruby 3.3.11, matching `.tool-versions` and `Gemfile`
- Bundler 2.4.5 or newer
- Redis
- Discord bot token
- OpenAI API key

This repository is intended to work on Linux, macOS, and Windows. The examples below use a POSIX-style shell for brevity; when using PowerShell or `cmd.exe`, keep the same values but use your shell's syntax for file copying and environment variable editing.

## Configuration

Create a `.env` file in the project root. The simplest approach is to copy `.env.sample` and fill in your secrets:

```bash
OPENAI_API_KEY=my_openai_secret
DISCORD_BOT_TOKEN=my_discord_secret
REDIS_URL=redis://localhost:6379/0
OPENAI_MODERATION_MODEL=omni-moderation-latest
OPENAI_REWRITE_MODEL=gpt-4.1-mini
HARASSMENT_CLASSIFIER_MODEL=gpt-4o-2024-08-06
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

`OPENAI_MODERATION_MODEL`, `OPENAI_REWRITE_MODEL`, `HARASSMENT_CLASSIFIER_MODEL`, `KARMA_AUTOMOD_THRESHOLD`, `KARMA_AUTOMOD_ACTION`, `KARMA_TIMEOUT_SECONDS`, `LOG_INVITE_URL`, and `LOG_FORMAT` are optional. `TELEMETRY_HASH_SALT` is used to anonymize Discord identifiers in logs and traces; set it to a stable random secret for your deployment.

## Local Development

Install dependencies:

```bash
gem install bundler -v 2.4.5
bundle install
```

Start Redis:

```bash
docker compose up redis
```

If you are not using Docker, point `REDIS_URL` at any reachable Redis instance.

Run the bot:

```bash
bundle exec ruby bot.rb
```

Run tests:

```bash
bundle exec rspec
```

The default specs stub OpenAI and Redis, so they do not require external API calls.

The Redis data model is documented in `docs/data-model.md`.
The application structure is documented in `docs/architecture.md`.

## Logging

The bot emits structured logs by default using JSON lines. Each entry includes a timestamp, level, event name, and any event-specific fields.

Use `LOG_FORMAT=plain` if you want a more human-oriented log format during local development.

## Plugins

Optional built-in plugins can be enabled with `PLUGINS`, using comma-separated names:

```bash
PLUGINS=telemetry
```

Built-in plugins:

- `harassment`
- `telemetry`
- `personality`

The `harassment` plugin passively captures interaction events, enqueues harassment classification work, and records classified incidents in its own read model without applying automated enforcement.

When the `harassment` plugin is enabled, moderators can inspect the derived signals directly from Discord with:

```bash
!moderation harassment risk @user
!moderation harassment pair @user_a @user_b
!moderation harassment incidents 3
```

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

Available personalities are `objective`, `empathetic`, `pirate`, and `poetic`. The default is `objective`, which uses a direct, neutral rewrite style.

## Docker

Run the bot and Redis together:

```bash
docker compose up --build
```

The bot service reads secrets from `.env`. Inside Compose, `REDIS_URL` is set to `redis://redis:6379/0`. Redis uses append-only persistence with `appendfsync everysec`, and stores local state in `./redis-data`.

## OpenTelemetry

Optional OpenTelemetry settings can be added to `.env`:

```bash
PLUGINS=telemetry
TELEMETRY_ENABLED=true
OTEL_EXPORTER_OTLP_ENDPOINT=https://api.honeycomb.io
OTEL_EXPORTER_OTLP_HEADERS=x-honeycomb-team=secretkey
OTEL_SERVICE_NAME=ModerationGPT
```

OpenTelemetry is disabled by default. Identifier anonymization still runs when telemetry is disabled. Enable the telemetry plugin explicitly with `PLUGINS=telemetry`, then set `TELEMETRY_ENABLED=true` to turn on OpenTelemetry inside that plugin. Install optional telemetry dependencies with `bundle config set --local with telemetry` before `bundle install` when enabling OpenTelemetry locally. For Docker, build with `BUNDLE_WITH=telemetry docker compose build`.
