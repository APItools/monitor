local concurredis = require "concurredis"
local h           = require 'controller_helpers'

local redis = {}

redis.stats = function(params)
  h.send_json({ stats = concurredis.stats(params.section) })
end

redis.keys = function(params)
  h.send_json({ keys = concurredis.keys() })
end

return redis
