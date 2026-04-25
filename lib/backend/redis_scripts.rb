module Backend
  module RedisScripts
    INCREMENT_KARMA_WITH_AUDIT = <<~LUA
      local event = {
        created_at = ARGV[6],
        delta = tonumber(ARGV[2]),
        source = ARGV[3],
        score = redis.call("HINCRBY", KEYS[1], ARGV[1], ARGV[2]),
      }

      if ARGV[4] ~= "" then
        event.actor_id = tonumber(ARGV[4])
      end

      if ARGV[5] ~= "" then
        event.reason = ARGV[5]
      end

      redis.call("LPUSH", KEYS[2], cjson.encode(event))
      redis.call("LTRIM", KEYS[2], 0, tonumber(ARGV[7]) - 1)

      return event.score
    LUA

    SET_KARMA_WITH_AUDIT = <<~LUA
      local previous = tonumber(redis.call("HGET", KEYS[1], ARGV[1]) or "0")
      local score = tonumber(ARGV[2])
      local event = {
        created_at = ARGV[6],
        delta = score - previous,
        score = score,
        source = ARGV[3],
      }

      if ARGV[4] ~= "" then
        event.actor_id = tonumber(ARGV[4])
      end

      if ARGV[5] ~= "" then
        event.reason = ARGV[5]
      end

      redis.call("HSET", KEYS[1], ARGV[1], score)
      redis.call("LPUSH", KEYS[2], cjson.encode(event))
      redis.call("LTRIM", KEYS[2], 0, tonumber(ARGV[7]) - 1)

      return score
    LUA

    RECORD_KARMA_EVENT = <<~LUA
      local event = {
        created_at = ARGV[4],
        delta = tonumber(ARGV[2]),
        score = tonumber(ARGV[1]),
        source = ARGV[3],
      }

      if ARGV[5] ~= "" then
        event.actor_id = tonumber(ARGV[5])
      end

      if ARGV[6] ~= "" then
        event.reason = ARGV[6]
      end

      redis.call("LPUSH", KEYS[1], cjson.encode(event))
      redis.call("LTRIM", KEYS[1], 0, tonumber(ARGV[7]) - 1)

      return event.score
    LUA
  end
end
