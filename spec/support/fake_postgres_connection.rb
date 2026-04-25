require "json"
require "time"

class FakePostgresConnection
  def initialize
    @interaction_events = []
  end

  def exec_params(sql, params)
    case sql
    when /INSERT INTO interaction_events/i
      insert_interaction_event(params)
    when /SELECT \*\s+FROM interaction_events\s+WHERE message_id = \$1\s+LIMIT 1/im
      find_interaction_event(params[0])
    when /UPDATE interaction_events\s+SET classification_status = \$2/im
      update_classification_status(params[0], params[1])
    when /SELECT \*\s+FROM interaction_events\s+WHERE classification_status = \$1/im
      list_by_status(params[0])
    when /SELECT \*\s+FROM interaction_events\s+WHERE content_retention_expires_at IS NOT NULL/im
      list_expired(params[0])
    when /UPDATE interaction_events\s+SET raw_content = \$2,\s+content_redacted_at = \$3/im
      redact_content(params[0], params[1], params[2])
    when /SELECT \*\s+FROM interaction_events\s+WHERE guild_id = \$1\s+AND channel_id = \$2/im
      recent_in_channel(params[0], params[1], params[2], params[3])
    when /SELECT \*\s+FROM interaction_events\s+WHERE guild_id = \$1\s+AND created_at < \$2/im
      recent_between_participants(params[0], params[1], params[2], params[3])
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

  def find_interaction_event(message_id)
    row = @interaction_events.find { |event| event["message_id"] == message_id.to_s }
    row ? [row] : []
  end

  def update_classification_status(message_id, status)
    row = @interaction_events.find { |event| event["message_id"] == message_id.to_s }
    return [] unless row

    row["classification_status"] = status
    [row]
  end

  def list_by_status(status)
    @interaction_events
      .select { |event| event["classification_status"] == status }
      .sort_by { |event| Time.parse(event["created_at"]).utc }
  end

  def list_expired(as_of)
    cutoff = Time.parse(as_of).utc
    @interaction_events
      .select do |event|
        expires_at = event["content_retention_expires_at"]
        expires_at && Time.parse(expires_at).utc <= cutoff && event["content_redacted_at"].nil?
      end
      .sort_by { |event| Time.parse(event["created_at"]).utc }
  end

  def redact_content(message_id, raw_content, redacted_at)
    row = @interaction_events.find { |event| event["message_id"] == message_id.to_s }
    return [] unless row

    row["raw_content"] = raw_content
    row["content_redacted_at"] = redacted_at
    [row]
  end

  def recent_in_channel(server_id, channel_id, before, limit)
    cutoff = Time.parse(before).utc
    @interaction_events
      .select do |event|
        event["guild_id"] == server_id.to_s &&
          event["channel_id"] == channel_id.to_s &&
          Time.parse(event["created_at"]).utc < cutoff
      end
      .sort_by { |event| Time.parse(event["created_at"]).utc }
      .first(limit.to_i)
  end

  def recent_between_participants(server_id, before, participant_ids, limit)
    cutoff = Time.parse(before).utc
    ids = Array(participant_ids).map(&:to_s)
    @interaction_events
      .select do |event|
        event["guild_id"] == server_id.to_s &&
          Time.parse(event["created_at"]).utc < cutoff &&
          interaction_involves_participants?(event, ids)
      end
      .sort_by { |event| Time.parse(event["created_at"]).utc }
      .first(limit.to_i)
  end

  def interaction_involves_participants?(event, participant_ids)
    participants = [event["author_id"], *JSON.parse(event["target_user_ids"])]
    !(participants & participant_ids).empty?
  end
end
