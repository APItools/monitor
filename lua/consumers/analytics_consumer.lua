local m   = require 'model_helpers'
local c   = require 'consumer_helpers'
local inspect = require 'inspect'

local analytics_consumer = {
  name = 'analytics',
  has_to_act_on = function(job)
    return job.level == 'analytics'
  end,
}

local next_job = c.next_job(analytics_consumer)

analytics_consumer.run = function()
  local job = next_job('events:' .. analytics_consumer.name)
end
