# OpenModBot

OpenModBot is a Discord moderation bot for text channels. It provides core AI-assisted message moderation, per-server watchlists, karma and review queues, optional automod actions, and a plugin system for storage, AI providers, admin notifications, telemetry, rewrite personalities, and passive harassment analysis.

## Highlights

- Deletes AI-flagged messages and rewrites flagged watchlist messages in a more constructive tone.
- Tracks per-server watchlists, karma scores, capped karma history, and moderation review queues.
- Supports shadow mode for reviewing would-be moderation actions before enforcing them.
- Uses in-memory moderation state by default, with optional Redis or Postgres-backed storage.
- Supports OpenAI by default and Gemini through the optional `google_ai` plugin.
- Provides optional plugins for harassment insights, admin notifications, telemetry, and rewrite personalities.

## Quick Start

Requirements:

- Ruby 3.3.11
- Bundler 2.4.5 or newer
- Discord bot token
- OpenAI API key, or Google AI API key when using `PLUGINS=google_ai`

Install dependencies:

```bash
gem install bundler -v 2.4.5
bundle install
```

Create `.env` from `.env.sample` and fill in at least:

```bash
DISCORD_BOT_TOKEN=my_discord_secret
OPENAI_API_KEY=my_openai_secret
```

Run the bot:

```bash
bundle exec ruby bot.rb
```

Run tests and lint:

```bash
bundle exec rspec
bundle exec rubocop
```

## Common Configurations

Use the default in-memory storage for local testing:

```bash
PLUGINS=
```

Use Redis-backed core moderation state:

```bash
bundle config set --local with redis
bundle install
PLUGINS=redis
REDIS_URL=redis://localhost:6379/0
```

Use Postgres-backed core moderation state:

```bash
bundle config set --local with postgres
bundle install
PLUGINS=postgres
DATABASE_URL=postgres://postgres:postgres@localhost:5432/openmodbot
```

Enable passive harassment insights:

```bash
bundle config set --local with postgres
bundle install
PLUGINS=postgres,harassment
DATABASE_URL=postgres://postgres:postgres@localhost:5432/openmodbot
```

Enable admin notifications:

```bash
PLUGINS=admin_notifications
ADMIN_NOTIFICATION_CHANNEL_ID=123456789012345678
```

## Documentation

The GitHub wiki carries the operator-facing documentation. In this workspace, the wiki is cloned next to the bot repository under `../wiki`.

- [Home](../wiki/Home.md)
- [Getting Started](../wiki/Getting-Started.md)
- [Configuration](../wiki/Configuration.md)
- [Moderation Commands](../wiki/Moderation-Commands.md)
- [Plugins](../wiki/Plugins.md)
- [Operations](../wiki/Operations.md)
- [Development](../wiki/Development.md)

Repository docs cover design and implementation details:

- [Architecture](docs/architecture.md)
- [Data model](docs/data-model.md)
- [Architecture decision records](docs/adrs/README.md)
- [Harassment Postgres cutover](docs/harassment-postgres-cutover.md)

## Built-In Plugins

- `openai`
- `google_ai`
- `redis`
- `postgres`
- `harassment` requires `postgres`
- `admin_notifications`
- `telemetry`
- `personality`

External plugins can follow the `OpenModBot::Plugin` hook interface and register with `OpenModBot::PluginRegistry.register`.
