local jor = require 'jor'
local m   = require 'model_helpers'
local consumer_helpers = {}
local inspect = require 'inspect'

-- discards events in a queue until it finds an event which matches
-- the conditions of the current consumer.
consumer_helpers.next_job = function(consumer)
  local function rec()
    --local queue = "events:".. consumer.name
    local queue = "events"
    local job =  m.find(queue, {channel = 'events:' .. consumer.name})
    if not job then return nil end
    if not consumer.has_to_act_on(job) then
      -- m.delete(queue, job._id)
      return rec(consumer)
    end
    return job
  end
  return rec
end

consumer_helpers.event_consumers = {
  all = function()
    return {} -- {require('consumers.mail')}
  end
}

return consumer_helpers
