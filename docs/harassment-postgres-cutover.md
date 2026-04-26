# Harassment Postgres Cutover

This runbook is the intended path for moving the harassment pipeline from Redis-backed state to the Postgres-backed runtime path.

## Goal

Use Postgres for the harassment runtime state:

- interaction events
- classification records
- classification jobs
- classification cache entries
- server rate-limit buckets

## Preconditions

- `DATABASE_URL` points to the target Postgres database
- the schema in `db/harassment/001_initial_schema.sql` has been applied
- Redis still contains the active harassment runtime state
- the bot is still running with `HARASSMENT_STORAGE_BACKEND=redis`

## Sequence

1. **Apply the schema**

   Make sure the Postgres database has the harassment tables and indexes from:

   - `db/harassment/001_initial_schema.sql`

2. **Bootstrap existing Redis state**

   Run:

   ```bash
   ruby scripts/bootstrap_harassment_postgres.rb
   ```

   This copies:

   - interaction events
   - classification records
   - classification jobs

   into Postgres.

3. **Verify Redis and Postgres counts plus spot checks**

   Run:

   ```bash
   ruby scripts/verify_harassment_postgres.rb
   ```

   Or, if you want to sanity-check specific known incidents as well:

   ```bash
   ruby scripts/verify_harassment_postgres.rb 123456789012345678 234567890123456789
   ```

   Confirm that totals and per-server counts match for:

   - `interaction_events`
   - `classification_records`
   - `classification_jobs`

   Also confirm that the spot checks report `matches=true` for the sampled:

   - `interaction_events`
   - `classification_records`
   - `classification_jobs`

   If you passed explicit message IDs, confirm those known-message checks also report `matches=true`.

4. **Pause and sanity-check**

   Before flipping the runtime, confirm:

   - the verification output reports `matches=true` for all three data sets
   - the verification spot checks also report `matches=true`
   - Postgres connectivity is stable
   - logs are clean

5. **Flip the backend**

   Set:

   ```bash
   HARASSMENT_STORAGE_BACKEND=postgres
   ```

   and restart the bot.

6. **Observe after cutover**

   Watch for:

   - successful ingestion of new interaction events
   - successful job progression from `pending` to `classified`
   - expected moderator query behavior
   - absence of repeated job failures

## Rollback

If the Postgres cutover misbehaves:

1. set `HARASSMENT_STORAGE_BACKEND=redis`
2. restart the bot
3. keep Postgres data for investigation; do not delete it immediately

Because Redis remains the source before cutover and the backend switch is configuration-driven, rollback is only a configuration change plus restart.

## Notes

- The bootstrap script is idempotent for already-migrated durable records.
- The verification script compares counts broadly and also performs a small sample of row-level spot checks.
- Cache and rate-limit state are not bootstrapped; they start fresh after cutover.
