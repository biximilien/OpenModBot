require "json"
require "time"
require_relative "fake_postgres/time_helpers"

class FakePostgresConnection
  include FakePostgres::TimeHelpers

  def initialize
    @interaction_events = []
    @classification_records = []
    @classification_jobs = []
    @classification_cache_entries = []
    @relationship_edges = []
    @server_rate_limits = []
  end

  def exec_params(sql, params)
    case sql
    when /INSERT INTO interaction_events/i
      insert_interaction_event(params)
    when /SELECT \*\s+FROM interaction_events\s+WHERE guild_id = \$1\s+AND message_id = \$2\s+LIMIT 1/im
      find_interaction_event(params[1], guild_id: params[0])
    when /UPDATE interaction_events\s+SET classification_status = \$3/im
      update_classification_status(params[1], params[2], guild_id: params[0])
    when /SELECT \*\s+FROM interaction_events\s+WHERE classification_status = \$1/im
      list_by_status(params[0])
    when /SELECT \*\s+FROM interaction_events\s+WHERE guild_id = \$1\s+AND classification_status = \$2/im
      list_classified_for_server(params[0], channel_id: params[2], author_id: params[3], since: params[4], limit: params[5])
    when /SELECT \*\s+FROM interaction_events\s+WHERE content_retention_expires_at IS NOT NULL/im
      list_expired(params[0])
    when /UPDATE interaction_events\s+SET raw_content = \$3,\s+content_redacted_at = \$4/im
      redact_content(params[1], params[2], params[3], guild_id: params[0])
    when /SELECT \*\s+FROM interaction_events\s+WHERE guild_id = \$1\s+AND channel_id = \$2/im
      recent_in_channel(params[0], params[1], params[2], params[3])
    when /SELECT \*\s+FROM interaction_events\s+WHERE guild_id = \$1\s+AND created_at < \$2/im
      recent_between_participants(params[0], params[1], params[2], params[3])
    when /INSERT INTO classification_records/i
      insert_classification_record(params)
    when /SELECT \*\s+FROM classification_records\s+WHERE guild_id = \$1\s+AND message_id = \$2\s+AND classifier_version = \$3\s+LIMIT 1/im
      find_classification_record(params[0], params[1], params[2])
    when /SELECT \*\s+FROM classification_records\s+WHERE guild_id = \$1\s+AND message_id = \$2\s+ORDER BY classified_at ASC/im
      all_classification_records_for_message(params[0], params[1])
    when /SELECT \*\s+FROM classification_records\s+WHERE guild_id = \$1\s+AND message_id = \$2\s+ORDER BY classified_at DESC\s+LIMIT 1/im
      latest_classification_record_for_message(params[0], params[1])
    when /INSERT INTO classification_jobs/i
      insert_classification_job(params)
    when /SELECT \*\s+FROM classification_jobs\s+WHERE guild_id = \$1\s+AND message_id = \$2\s+AND classifier_version = \$3\s+LIMIT 1/im
      find_classification_job(params[0], params[1], params[2])
    when /UPDATE classification_jobs\s+SET status = \$4/im
      update_classification_job(params)
    when /SELECT \*\s+FROM classification_jobs\s+WHERE available_at <= \$1\s+AND status IN \('pending', 'failed_retryable'\)/im
      due_classification_jobs(params[0])
    when /SELECT \*\s+FROM classification_cache_entries\s+WHERE cache_key = \$1\s+LIMIT 1/im
      find_classification_cache_entry(params[0])
    when /DELETE FROM classification_cache_entries\s+WHERE cache_key = \$1/im
      delete_classification_cache_entry(params[0])
    when /INSERT INTO classification_cache_entries/i
      upsert_classification_cache_entry(params)
    when /SELECT \*\s+FROM relationship_edges\s+WHERE guild_id = \$1\s+AND source_user_id = \$2\s+AND target_user_id = \$3\s+AND score_version = \$4\s+LIMIT 1/im
      find_relationship_edge(params[0], params[1], params[2], params[3])
    when /INSERT INTO relationship_edges/i
      upsert_relationship_edge(params)
    when /SELECT \*\s+FROM relationship_edges\s+WHERE guild_id = \$1\s+AND source_user_id = \$2\s+AND score_version = \$3/im
      outgoing_relationship_edges(params[0], params[1], params[2])
    when /SELECT \*\s+FROM relationship_edges\s+WHERE guild_id = \$1\s+AND target_user_id = \$2\s+AND score_version = \$3/im
      incoming_relationship_edges(params[0], params[1], params[2])
    when /DELETE FROM relationship_edges\s+WHERE guild_id = \$1\s+AND score_version = \$2/im
      delete_relationship_edges_for_server(params[0], params[1])
    when /DELETE FROM relationship_edges\s+WHERE score_version = \$1/im
      delete_relationship_edges_for_score_version(params[0])
    when /SELECT \*\s+FROM server_rate_limits\s+WHERE guild_id = \$1\s+LIMIT 1/im
      find_server_rate_limit(params[0])
    when /INSERT INTO server_rate_limits/i
      upsert_server_rate_limit(params)
    when /SELECT COUNT\(\*\) AS count\s+FROM interaction_events/im
      [{ "count" => @interaction_events.length }]
    when /SELECT guild_id, COUNT\(\*\) AS count\s+FROM interaction_events\s+GROUP BY guild_id/im
      grouped_counts(@interaction_events)
    when /SELECT COUNT\(\*\) AS count\s+FROM classification_records/im
      [{ "count" => @classification_records.length }]
    when /SELECT guild_id, COUNT\(\*\) AS count\s+FROM classification_records\s+GROUP BY guild_id/im
      grouped_counts(@classification_records)
    when /SELECT COUNT\(\*\) AS count\s+FROM classification_jobs/im
      [{ "count" => @classification_jobs.length }]
    when /SELECT guild_id, COUNT\(\*\) AS count\s+FROM classification_jobs\s+GROUP BY guild_id/im
      grouped_counts(@classification_jobs)
    when /SELECT COUNT\(\*\) AS count\s+FROM relationship_edges/im
      [{ "count" => @relationship_edges.length }]
    when /SELECT guild_id, COUNT\(\*\) AS count\s+FROM relationship_edges\s+GROUP BY guild_id/im
      grouped_counts(@relationship_edges)
    else
      raise "Unsupported SQL: #{sql}"
    end
  end

  private

  def insert_interaction_event(params)
    guild_id, message_id, author_id, channel_id, target_user_ids, raw_content, classification_status, retention_expires_at, redacted_at, created_at = params
    return [] if @interaction_events.any? { |event| event["guild_id"] == guild_id && event["message_id"] == message_id }

    row = {
      "guild_id" => guild_id,
      "message_id" => message_id,
      "author_id" => author_id,
      "channel_id" => channel_id,
      "target_user_ids" => target_user_ids,
      "raw_content" => raw_content,
      "classification_status" => classification_status,
      "content_retention_expires_at" => retention_expires_at,
      "content_redacted_at" => redacted_at,
      "created_at" => created_at,
    }
    @interaction_events << row
    [row]
  end

  def find_interaction_event(message_id, guild_id:)
    row = @interaction_events.find do |event|
      event["message_id"] == message_id.to_s &&
        event["guild_id"] == guild_id.to_s
    end
    row ? [row] : []
  end

  def update_classification_status(message_id, status, guild_id:)
    row = @interaction_events.find do |event|
      event["message_id"] == message_id.to_s &&
        event["guild_id"] == guild_id.to_s
    end
    return [] unless row

    row["classification_status"] = status
    [row]
  end

  def list_by_status(status)
    @interaction_events
      .select { |event| event["classification_status"] == status }
      .sort_by { |event| parse_utc(event["created_at"]) }
  end

  def list_classified_for_server(server_id, channel_id:, author_id:, since:, limit:)
    rows = @interaction_events
      .select do |event|
        event["guild_id"] == server_id.to_s &&
          event["classification_status"] == Harassment::ClassificationStatus::CLASSIFIED &&
          (channel_id.nil? || event["channel_id"] == channel_id.to_s) &&
          (author_id.nil? || event["author_id"] == author_id.to_s) &&
          (since.nil? || parse_utc(event["created_at"]) >= parse_utc(since))
      end
      .sort_by { |event| parse_utc(event["created_at"]) }

    limit ? rows.last(limit.to_i) : rows
  end

  def list_expired(as_of)
    cutoff = parse_utc(as_of)
    @interaction_events
      .select do |event|
        expires_at = event["content_retention_expires_at"]
        expires_at && parse_utc(expires_at) <= cutoff && event["content_redacted_at"].nil?
      end
      .sort_by { |event| parse_utc(event["created_at"]) }
  end

  def redact_content(message_id, raw_content, redacted_at, guild_id:)
    row = @interaction_events.find do |event|
      event["message_id"] == message_id.to_s &&
        event["guild_id"] == guild_id.to_s
    end
    return [] unless row

    row["raw_content"] = raw_content
    row["content_redacted_at"] = redacted_at
    [row]
  end

  def recent_in_channel(server_id, channel_id, before, limit)
    cutoff = parse_utc(before)
    @interaction_events
      .select do |event|
        event["guild_id"] == server_id.to_s &&
          event["channel_id"] == channel_id.to_s &&
          parse_utc(event["created_at"]) < cutoff
      end
      .sort_by { |event| parse_utc(event["created_at"]) }
      .last(limit.to_i)
  end

  def recent_between_participants(server_id, before, participant_ids, limit)
    cutoff = parse_utc(before)
    ids = Array(participant_ids).map(&:to_s)
    @interaction_events
      .select do |event|
        event["guild_id"] == server_id.to_s &&
          parse_utc(event["created_at"]) < cutoff &&
          interaction_involves_participants?(event, ids)
      end
      .sort_by { |event| parse_utc(event["created_at"]) }
      .last(limit.to_i)
  end

  def interaction_involves_participants?(event, participant_ids)
    participants = [event["author_id"], *JSON.parse(event["target_user_ids"])]
    !(participants & participant_ids).empty?
  end

  def insert_classification_record(params)
    guild_id, message_id, classifier_version, model_version, prompt_version, classification, severity_score, confidence, classified_at = params
    return [] if @classification_records.any? do |record|
      record["guild_id"] == guild_id &&
        record["message_id"] == message_id &&
        record["classifier_version"] == classifier_version
    end

    row = {
      "guild_id" => guild_id,
      "message_id" => message_id,
      "classifier_version" => classifier_version,
      "model_version" => model_version,
      "prompt_version" => prompt_version,
      "classification" => classification,
      "severity_score" => severity_score,
      "confidence" => confidence,
      "classified_at" => classified_at,
    }
    @classification_records << row
    [row]
  end

  def find_classification_record(guild_id, message_id, classifier_version)
    row = @classification_records.find do |record|
      record["guild_id"] == guild_id.to_s &&
        record["message_id"] == message_id.to_s &&
        record["classifier_version"] == classifier_version.to_s
    end
    row ? [row] : []
  end

  def all_classification_records_for_message(guild_id, message_id)
    @classification_records
      .select { |record| record["guild_id"] == guild_id.to_s && record["message_id"] == message_id.to_s }
      .sort_by { |record| parse_utc(record["classified_at"]) }
  end

  def latest_classification_record_for_message(guild_id, message_id)
    row = all_classification_records_for_message(guild_id, message_id).last
    row ? [row] : []
  end

  def insert_classification_job(params)
    guild_id, message_id, classifier_version, status, attempt_count, available_at, last_error_class, last_error_message, enqueued_at, updated_at = params
    return [] if @classification_jobs.any? do |job|
      job["guild_id"] == guild_id &&
        job["message_id"] == message_id &&
        job["classifier_version"] == classifier_version
    end

    row = {
      "guild_id" => guild_id,
      "message_id" => message_id,
      "classifier_version" => classifier_version,
      "status" => status,
      "attempt_count" => attempt_count,
      "available_at" => available_at,
      "last_error_class" => last_error_class,
      "last_error_message" => last_error_message,
      "enqueued_at" => enqueued_at,
      "updated_at" => updated_at,
    }
    @classification_jobs << row
    [row]
  end

  def find_classification_job(guild_id, message_id, classifier_version)
    row = @classification_jobs.find do |job|
      job["guild_id"] == guild_id.to_s &&
        job["message_id"] == message_id.to_s &&
        job["classifier_version"] == classifier_version.to_s
    end
    row ? [row] : []
  end

  def update_classification_job(params)
    guild_id, message_id, classifier_version, status, attempt_count, available_at, last_error_class, last_error_message, enqueued_at, updated_at = params
    row = @classification_jobs.find do |job|
      job["guild_id"] == guild_id.to_s &&
        job["message_id"] == message_id.to_s &&
        job["classifier_version"] == classifier_version.to_s
    end
    return [] unless row

    row["status"] = status
    row["attempt_count"] = attempt_count
    row["available_at"] = available_at
    row["last_error_class"] = last_error_class
    row["last_error_message"] = last_error_message
    row["enqueued_at"] = enqueued_at
    row["updated_at"] = updated_at
    [row]
  end

  def due_classification_jobs(as_of)
    cutoff = parse_utc(as_of)
    @classification_jobs
      .select do |job|
        parse_utc(job["available_at"]) <= cutoff &&
          %w[pending failed_retryable].include?(job["status"])
      end
      .sort_by { |job| parse_utc(job["available_at"]) }
  end

  def find_classification_cache_entry(cache_key)
    row = @classification_cache_entries.find { |entry| entry["cache_key"] == cache_key.to_s }
    row ? [row] : []
  end

  def delete_classification_cache_entry(cache_key)
    @classification_cache_entries.reject! { |entry| entry["cache_key"] == cache_key.to_s }
    []
  end

  def upsert_classification_cache_entry(params)
    cache_key, record_payload, expires_at = params
    row = @classification_cache_entries.find { |entry| entry["cache_key"] == cache_key.to_s }
    if row
      row["record_payload"] = record_payload
      row["expires_at"] = expires_at
    else
      row = {
        "cache_key" => cache_key,
        "record_payload" => record_payload,
        "expires_at" => expires_at,
      }
      @classification_cache_entries << row
    end
    [row]
  end

  def find_relationship_edge(guild_id, source_user_id, target_user_id, score_version)
    row = @relationship_edges.find do |edge|
      edge["guild_id"] == guild_id.to_s &&
        edge["source_user_id"] == source_user_id.to_s &&
        edge["target_user_id"] == target_user_id.to_s &&
        edge["score_version"] == score_version.to_s
    end
    row ? [row] : []
  end

  def upsert_relationship_edge(params)
    guild_id, source_user_id, target_user_id, score_version, hostility_score, positive_score, interaction_count, last_interaction_at = params
    row = @relationship_edges.find do |edge|
      edge["guild_id"] == guild_id.to_s &&
        edge["source_user_id"] == source_user_id.to_s &&
        edge["target_user_id"] == target_user_id.to_s &&
        edge["score_version"] == score_version.to_s
    end

    if row
      row["hostility_score"] = hostility_score
      row["positive_score"] = positive_score
      row["interaction_count"] = interaction_count
      row["last_interaction_at"] = last_interaction_at
    else
      row = {
        "guild_id" => guild_id,
        "source_user_id" => source_user_id,
        "target_user_id" => target_user_id,
        "score_version" => score_version,
        "hostility_score" => hostility_score,
        "positive_score" => positive_score,
        "interaction_count" => interaction_count,
        "last_interaction_at" => last_interaction_at,
      }
      @relationship_edges << row
    end
    [row]
  end

  def outgoing_relationship_edges(guild_id, source_user_id, score_version)
    @relationship_edges
      .select do |edge|
        edge["guild_id"] == guild_id.to_s &&
          edge["source_user_id"] == source_user_id.to_s &&
          edge["score_version"] == score_version.to_s
      end
      .sort_by { |edge| edge["target_user_id"] }
  end

  def incoming_relationship_edges(guild_id, target_user_id, score_version)
    @relationship_edges
      .select do |edge|
        edge["guild_id"] == guild_id.to_s &&
          edge["target_user_id"] == target_user_id.to_s &&
          edge["score_version"] == score_version.to_s
      end
      .sort_by { |edge| edge["source_user_id"] }
  end

  def delete_relationship_edges_for_server(guild_id, score_version)
    @relationship_edges.reject! do |edge|
      edge["guild_id"] == guild_id.to_s && edge["score_version"] == score_version.to_s
    end
    []
  end

  def delete_relationship_edges_for_score_version(score_version)
    @relationship_edges.reject! { |edge| edge["score_version"] == score_version.to_s }
    []
  end

  def find_server_rate_limit(guild_id)
    row = @server_rate_limits.find { |entry| entry["guild_id"] == guild_id.to_s }
    row ? [row] : []
  end

  def upsert_server_rate_limit(params)
    guild_id, timestamps = params
    row = @server_rate_limits.find { |entry| entry["guild_id"] == guild_id.to_s }
    if row
      row["timestamps"] = timestamps
    else
      row = {
        "guild_id" => guild_id,
        "timestamps" => timestamps,
      }
      @server_rate_limits << row
    end
    [row]
  end

  def grouped_counts(rows)
    rows
      .group_by { |row| row["guild_id"] }
      .sort.to_h
      .map { |guild_id, entries| { "guild_id" => guild_id, "count" => entries.length } }
  end
end

