local Model   = require 'model'

local Event   = require 'models.event'
local sandbox = require 'sandbox'

local EventObserver      = Model:new()
EventObserver.collection = 'event_observers'
EventObserver.excluded_fields_to_index = {}

-- EventObserver:
-- {
--   condition:           <lua code>
--   action:              <lua code>
--   frequency:           <number> how often to check, in seconds
--   sustained_frequency: <number> for how long the condition needs to be true before triggering the action. Defaults to 0
--
--   -- Internal:
--   running:             <number> the running time (starts at 0, resets every time it is >= frequency)
--   sustained_running:   <number> for how long the condition needs to be true before triggering the action. Defaults to 0
--   _id: id
--}

local execute_sandboxed = function(lua_str, env, ...)
  local chunk      = assert(loadstring(lua_str))
  local safe_chunk = sandbox.run(chunk, {env = env})
  return safe_chunk(...)
end

local check_condition = function(eo, event)
  return execute_sandboxed(eo.condition, {}, event)
end

local execute_action = function(eo, event)
  local env = {
    send_event = function(ev) Event:create(ev) end
  }
  return execute_sandboxed(eo.action, env, event)
end

local function update_event_observer_action(eo, event)
  if eo.sustained_frequency == 0 then
    execute_action(eo, event)
  else
    eo.sustained_running = eo.sustained_running + eo.frequency
    while eo.sustained_running >= eo.sustained_frequency do
      eo.sustained_running = eo.sustained_running - eo.sustained_frequency
      execute_action(eo, event)
    end
  end
end

local function matches_any_event(eo, events)
  for _,event in ipairs(events) do
    if check_condition(eo, event) then return event end
  end
end

local function update_event_observer(eo, dt, events)
  eo.running = eo.running + dt
  while eo.running >= eo.frequency do
    eo.running = eo.running - eo.frequency
    local event = matches_any_event(eo, events)
    if event then
      update_event_observer_action(eo, event)
    else
      eo.sustained_running = 0
    end
  end
  EventObserver:update({_id = eo._id}, eo)
end

function EventObserver:create(eo, options)
  if not eo or not eo.action or not eo.condition or not eo.frequency then
    error("invalid event_observer, need at least an action, a condition and a frequency")
  end
  eo.sustained_frequency  = eo.sustained_frequency or 0
  eo.running              = 0
  eo.sustained_running    = 0

  return Model.create(self, eo, options)
end

function EventObserver:process_events(dt)
  local event_observers = self:all()
  local events          = Event:get_unprocessed()

  for _,eo in ipairs(event_observers) do
    update_event_observer(eo, dt, events)
  end

  for _,event in ipairs(events) do
    Event:update({_id = event._id}, {read = false})
    Event:update({_id = event._id}, {read = true})
  end
end

return EventObserver
