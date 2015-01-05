------------
--- Event
-- Event Model.
-- @module middleware

local Model   = require 'model'
local inspect = require 'inspect'
local e       = require 'consumer_helpers'

--- Event
-- @type Event
local Event = Model:new()

local ONE_DAY = 60*60*24 -- secs in a day
local LEVELS = {}
local LEVELS_DICT = {}
for level in ("log debug info warn error"):gmatch("%w+") do
  LEVELS_DICT[level] = true
  LEVELS[#LEVELS + 1] = level
end

Event.collection = 'events'
Event.excluded_fields_to_index = {}

-- in user_config collection, we have our user configuration and state
-- of read/unread events.  we read from the last_processed_event_id
-- up, and enqueue a job for mail if  we have to

-- local generate_unique_id = function(event)
--   local key = "brainslug"
--   local src = event.
--   return ngx.hmac_sha1(
-- end


function Event:create(event, options)
  --- channel
  -- required attribute, can be for example middleware, email, stats, ...
  -- @field[type=string] event.channel

  --- level
  -- one of the {'log', 'debug', 'info', 'warn', 'error' }
  -- @field[type=string] event.level

  --- msg
  -- required attribute, a message of the event
  -- @field[type=string] event.msg

  if not event or not event.channel or not event.level or not event.msg then
    error("invalid event, it should have at least channel, level and msg")
  end
  if not LEVELS_DICT[event.level] then
    error("invalid event level: " .. tostring(event.level) .. ", it must be one of: " .. table.concat(LEVELS, ", "))
  end
  event.read = false

  return Model.create(self, event, options)

  -- for _,consumer in pairs(e.event_consumers.all()) do
  --   ngx.log(0, inspect(consumer))
  --   m.create("events:".. consumer.name, event)
  -- end
end

function Event:purge_old(timestamp)
  local now = ngx.time()
  self:delete_or_error({created_at = {['$lt'] = now - ONE_DAY }} , 'events not found')
end

function Event:delete_expired(limit)
  Model:check_dots(self, Event, 'delete_expired')
  for i,level in ipairs(LEVELS) do
    if self:count() < limit then return end

    local last_to_keep = self:get_last_id() - limit
    self:delete({ _id = { ['$lte'] = last_to_keep }, level = level })
  end
  return
end

function Event:get_unprocessed()
  -- local user = m.find("user_config", {})
  -- local last_id
  -- if user then
  --   last_id = user.last_procesed_event_id
  -- else
  --   last_id = 0
  -- end
  -- return self:all({_id = {['$gte'] = last_id }})
  return self:all({read = false})
end

-- event_observers = {{filter = "",action = ".,." }}

return Event
