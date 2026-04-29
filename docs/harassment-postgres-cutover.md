# Harassment Postgres Cutover

This runbook is for older deployments that need to move historical harassment pipeline data from Redis-backed state to the current Postgres-backed runtime path.

## Goal

Use Postgres for the harassment runtime state:

- interaction events
- classification records
- classification jobs
- classification cache entries
- server rate-limit buckets
- relationship-edge projections

## Preconditions

- `DATABASE_URL` points to the target Postgres database
- the optional `redis` and `postgres` plugin dependency groups have been installed
- the schema in `db/harassment/001_initial_schema.sql` has been applied
- Redis still contains the historical harassment runtime state to migrate

## Sequence

1. **Apply the schema**

   Make sure the Postgres database has the harassment tables and indexes from:

   - `db/harassment/001_initial_schema.sql`

2. **Bootstrap existing Redis state**

   Run:

   ```bash
   PLUGINS=redis,postgres
   ruby scripts/bootstrap_harassment_postgres.rb
   ```

   This copies:

   - interaction events
   - classification records
   - classification jobs

   into Postgres.

3. **Rebuild relationship-edge projections**

   Run:

   ```bash
   PLUGINS=postgres
   ruby scripts/rebuild_harassment_relationship_edges.rb
   ```

   If you want to rebuild only one server:

   ```bash
   PLUGINS=postgres
   ruby scripts/rebuild_harassment_relationship_edges.rb 123456789012345678
   ```

   This rebuilds the current `score_version` relationship-edge projections from stored classified interaction events and their latest stored classification records.

   The moderator-facing incident and risk queries also read from those stored interaction events and classification records after boot, so they do not rely only on process-local incident state.

4. **Verify Redis and Postgres counts plus spot checks**

   Run:

   ```bash
   PLUGINS=redis,postgres
   ruby scripts/verify_harassment_postgres.rb
   ```

   Or, if you want to sanity-check specific known incidents as well:

   ```bash
   PLUGINS=redis,postgres
   ruby scripts/verify_harassment_postgres.rb 123456789012345678 234567890123456789
   ```

   Confirm that totals and per-server counts match for:

   - `interaction_events`
   - `classification_records`
   - `classification_jobs`

   Also confirm that `relationship_edges` shows the expected Postgres counts after the rebuild step.

   Also confirm that the spot checks report `matches=true` for the sampled:

   - `interaction_events`
   - `classification_records`
   - `classification_jobs`

   If you passed explicit message IDs, confirm those known-message checks also report `matches=true`.

5. **Pause and sanity-check**

   Before flipping the runtime, confirm:

   - the verification output reports `matches=true` for all three data sets
   - the verification spot checks also report `matches=true`
   - Postgres connectivity is stable
   - logs are clean

6. **Enable harassment on Postgres**

   Set:

   ```bash
   PLUGINS=postgres,harassment
   ```

   and restart the bot.

7. **Observe after cutover**

   Watch for:

   - successful ingestion of new interaction events
   - successful job progression from `pending` to `classified`
   - expected moderator query behavior
   - absence of repeated job failures

## Rollback

If the Postgres cutover misbehaves, disable the `harassment` plugin while investigating and keep Postgres data for analysis. The current harassment runtime requires Postgres.

## Notes

- The bootstrap script is idempotent for already-migrated durable records.
- The relationship-edge rebuild script clears and rebuilds the current `score_version` projection from stored classified events and their latest stored classification records.
- The verification script compares counts broadly, reports Postgres relationship-edge counts, and performs a small sample of row-level spot checks.
- Cache and rate-limit state are not bootstrapped; they start fresh after cutover.
