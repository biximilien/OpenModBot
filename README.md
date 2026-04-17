# ModerationGPT

ModerationGPT is a Discord moderation bot for text channels. It uses OpenAI's moderation endpoint to classify messages, Redis to store per-server watchlists, and the OpenAI Responses API to rewrite flagged messages from watched users in a more constructive tone.

## How It Works

The bot listens for Discord messages and applies two moderation paths:

- Watched users: flagged messages are deleted and replaced with a rewritten version.
- Other users: flagged messages are deleted.

Administrators can manage the watch list with:

```bash
!moderation watchlist
!moderation watchlist add @user
!moderation watchlist remove @user
```

## Requirements

- Ruby 2.7.7, matching `.tool-versions` and `Gemfile`
- Bundler
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
```

`OPENAI_MODERATION_MODEL` and `OPENAI_REWRITE_MODEL` are optional. The defaults are shown above.

## Local Development

Install dependencies:

```bash
bundle install
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
