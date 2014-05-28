local h         = require 'controller_helpers'
local inspect   = require 'inspect'
local EventObs  = require 'models.event_observer'
local Event     = require 'models.event'

local events = {

  count = function(params)
    local conditions, options = h.jor_conditions_and_options(params, '$gt')
    if params.read ~= nil then
      conditions.read = (params.read and params.read ~= "") or false
    end

    local count = Event:count(conditions, options)
    h.send_json({document_count = count})
  end,

  -- Index can be used as a search. Parameters:
  -- query: condition for the search
  -- per_page: optional, defaults to 20
  -- page: optional, defaults to 0
  -- from: optional, will start the search on a given _id

  index = function(params)
    params.query = params.query or '{}'
    local conditions, options = h.jor_conditions_and_options(params)

    if params.read ~= nil then
      conditions.read = (params.read and params.read ~= "") or false
    end

    local results = Event:all(conditions, options)

    h.send_json(results)
  end,

  show = function(params)
    local event = Event:find_or_error(params.id)
    h.send_json(event)
  end,

  create = function(params)
    h.send_json(Event:create({channel = "syslog", level = "info", msg = 'test', read = false }))
  end,

  delete = function(params)
    local event = Event:delete(params.id)
    h.send_json(event)
  end,

  delete_all = function(params)
    local event = Event:delete({})
    h.send_json(event)
  end,

  star = function(params)
    local event = Event:update(params.id, { starred = true })
    h.send_json(event)
  end,

  unstar = function(params)
    local event = Event:update(params.id, { starred = false })
    h.send_json(event)
  end,

  force_process = function(params)
    -- Event.process_
  end,

  expire = function(params)
    local deleted = Event:delete_expired()
    h.send_json({deleted = deleted})
  end
}
return events
