# ModerationGPT

ModerationGPT is a Discord moderation bot for text channels. It uses OpenAI's moderation endpoint to classify messages, Redis to store per-server watchlists, and the OpenAI Responses API to rewrite flagged messages from watched users in a more constructive tone.

## How It Works

The bot listens for Discord messages and applies two moderation paths:

- Watched users: flagged messages are deleted and replaced with a rewritten version.
- Other users: flagged messages are deleted.

Administrators can manage moderation state with:

```bash
!moderation watchlist
!moderation watchlist add @user
!moderation watchlist remove @user
!moderation karma @user
!moderation karma reset @user
!moderation karma add @user 1
!moderation karma remove @user 1
```

Each moderated infraction decreases the user's per-server karma score. When a score reaches `KARMA_AUTOMOD_THRESHOLD`, the bot applies `KARMA_AUTOMOD_ACTION`. Supported actions are `log_only`, `timeout`, `kick`, and `ban`; the default is `timeout`. Timeout requires the Discord moderate-members permission, which is included in the generated invite URL.

## Requirements

- Ruby 3.3.11, matching `.tool-versions` and `Gemfile`
- Bundler 2.4.5 or newer
- Redis
- Discord bot token
- OpenAI API key

## Configuration

Create a `.env` file in the project root:

```bash
OPENAI_API_KEY=my_openai_secret
DISCORD_BOT_TOKEN=my_discord_secret
REDIS_URL=redis://localhost:6379/0
OPENAI_MODERATION_MODEL=omni-moderation-latest
OPENAI_REWRITE_MODEL=gpt-4.1-mini
KARMA_AUTOMOD_THRESHOLD=-5
KARMA_AUTOMOD_ACTION=timeout
KARMA_TIMEOUT_SECONDS=3600
LOG_INVITE_URL=false
TELEMETRY_HASH_SALT=replace_with_random_secret
```

`OPENAI_MODERATION_MODEL`, `OPENAI_REWRITE_MODEL`, `KARMA_AUTOMOD_THRESHOLD`, `KARMA_AUTOMOD_ACTION`, `KARMA_TIMEOUT_SECONDS`, and `LOG_INVITE_URL` are optional. `TELEMETRY_HASH_SALT` is used to anonymize Discord identifiers in logs and traces; set it to a stable random secret for your deployment.

## Local Development

Install dependencies:

```bash
gem install bundler -v 2.4.5
bundle _2.4.5_ install
```

Start Redis:

```bash
docker compose up redis
```

Run the bot:

```bash
bundle exec ruby bot.rb
```

Run tests:

```bash
bundle exec rspec
```

The default specs stub OpenAI and Redis, so they do not require external API calls.

## Docker

Run the bot and Redis together:

```bash
docker compose up --build
```

The bot service reads secrets from `.env`. Inside Compose, `REDIS_URL` is set to `redis://redis:6379/0`.

## OpenTelemetry

Optional OpenTelemetry settings can be added to `.env`:

```bash
OTEL_EXPORTER_OTLP_ENDPOINT=https://api.honeycomb.io
OTEL_EXPORTER_OTLP_HEADERS=x-honeycomb-team=secretkey
OTEL_SERVICE_NAME=ModerationGPT
```
