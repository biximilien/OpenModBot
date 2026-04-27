CREATE TABLE interaction_events (
  id BIGSERIAL PRIMARY KEY,
  guild_id TEXT NOT NULL,
  message_id TEXT NOT NULL,
  author_id TEXT NOT NULL,
  channel_id TEXT NOT NULL,
  target_user_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
  raw_content TEXT,
  classification_status TEXT NOT NULL,
  content_retention_expires_at TIMESTAMPTZ,
  content_redacted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL
);

CREATE UNIQUE INDEX interaction_events_guild_message_uidx
  ON interaction_events (guild_id, message_id);

CREATE INDEX interaction_events_guild_author_created_idx
  ON interaction_events (guild_id, author_id, created_at);

CREATE INDEX interaction_events_guild_channel_created_idx
  ON interaction_events (guild_id, channel_id, created_at);

CREATE INDEX interaction_events_guild_status_channel_created_idx
  ON interaction_events (guild_id, classification_status, channel_id, created_at);

CREATE INDEX interaction_events_guild_status_author_created_idx
  ON interaction_events (guild_id, classification_status, author_id, created_at);

CREATE INDEX interaction_events_target_user_ids_gin_idx
  ON interaction_events
  USING GIN (target_user_ids);

CREATE TABLE classification_records (
  id BIGSERIAL PRIMARY KEY,
  guild_id TEXT NOT NULL,
  message_id TEXT NOT NULL,
  classifier_version TEXT NOT NULL,
  model_version TEXT NOT NULL,
  prompt_version TEXT NOT NULL,
  classification JSONB NOT NULL,
  severity_score DOUBLE PRECISION NOT NULL,
  confidence DOUBLE PRECISION NOT NULL,
  classified_at TIMESTAMPTZ NOT NULL
);

CREATE UNIQUE INDEX classification_records_guild_message_classifier_uidx
  ON classification_records (guild_id, message_id, classifier_version);

CREATE INDEX classification_records_guild_classified_at_idx
  ON classification_records (guild_id, classified_at);

CREATE INDEX classification_records_classification_gin_idx
  ON classification_records
  USING GIN (classification);

CREATE TABLE classification_jobs (
  id BIGSERIAL PRIMARY KEY,
  guild_id TEXT NOT NULL,
  message_id TEXT NOT NULL,
  classifier_version TEXT NOT NULL,
  status TEXT NOT NULL,
  attempt_count INTEGER NOT NULL,
  available_at TIMESTAMPTZ NOT NULL,
  last_error_class TEXT,
  last_error_message TEXT,
  enqueued_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);

CREATE UNIQUE INDEX classification_jobs_guild_message_classifier_uidx
  ON classification_jobs (guild_id, message_id, classifier_version);

CREATE INDEX classification_jobs_available_status_idx
  ON classification_jobs (available_at, status);

CREATE TABLE classification_cache_entries (
  id BIGSERIAL PRIMARY KEY,
  cache_key TEXT NOT NULL,
  record_payload JSONB NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL
);

CREATE UNIQUE INDEX classification_cache_entries_cache_key_uidx
  ON classification_cache_entries (cache_key);

CREATE INDEX classification_cache_entries_expires_at_idx
  ON classification_cache_entries (expires_at);

CREATE TABLE server_rate_limits (
  id BIGSERIAL PRIMARY KEY,
  guild_id TEXT NOT NULL,
  timestamps JSONB NOT NULL DEFAULT '[]'::jsonb
);

CREATE UNIQUE INDEX server_rate_limits_guild_uidx
  ON server_rate_limits (guild_id);

CREATE TABLE relationship_edges (
  id BIGSERIAL PRIMARY KEY,
  guild_id TEXT NOT NULL,
  source_user_id TEXT NOT NULL,
  target_user_id TEXT NOT NULL,
  score_version TEXT NOT NULL,
  hostility_score DOUBLE PRECISION NOT NULL,
  positive_score DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  interaction_count INTEGER NOT NULL,
  last_interaction_at TIMESTAMPTZ NOT NULL
);

CREATE UNIQUE INDEX relationship_edges_guild_source_target_score_uidx
  ON relationship_edges (guild_id, source_user_id, target_user_id, score_version);

CREATE INDEX relationship_edges_guild_source_idx
  ON relationship_edges (guild_id, source_user_id, score_version);

CREATE INDEX relationship_edges_guild_target_idx
  ON relationship_edges (guild_id, target_user_id, score_version);
