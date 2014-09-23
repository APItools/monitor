local h   = require 'controller_helpers'
local m   = require 'model_helpers'
local Event = require 'models.event'
local Trace = require 'models.trace'

local inspect = require 'inspect'

local NOT_FOUND = 'trace not found'

local function search(params)
  return h.jor_conditions_and_options(params)
end

local traces = {

  count = function(params)
    local conditions, options = h.jor_conditions_and_options(params, '$gt')
		local count = Trace:count(conditions, options)
    h.send_json({document_count = count})
  end,

  uuid = function(params)
    local trace = Trace:find_or_error({uuid = params.uuid}, NOT_FOUND)
    h.send_json(trace)
  end,

  index = function(params)
    params.last_id = params.last_id or Trace:get_last_id()
    local conditions, options = h.jor_conditions_and_options(params)

    local results = Trace:all(conditions, options)
    h.send_json(results)
  end,

  index_saved = function(params)
    local results = Trace:all({starred = true})

    h.send_json(results)
  end,

  last_id = function(params)
    h.send_json({ last_id = Trace:get_last_id() })
  end,

  create = function(params)
    local trace = Trace:new(h.request_json())
    trace.starred = false
    Trace.create(trace)

    Event:create({channel = "syslog", level = "info",
                  msg = "Traces " .. trace._id .. " created."   })

    h.send_json(trace, ngx.HTTP_CREATED)
  end,

  search = function(params)
    h.send_json(Trace:all(search(params)))
  end,

  search_for_index = function(params)
    h.send_json(Trace:for_index(search(params)))
  end,

  show = function(params)
    local trace = Trace:one(params.id, NOT_FOUND)
    h.send_json(trace)
  end,

  delete = function(params)
    Trace:delete_or_error(params.id, NOT_FOUND)
  end,

  delete_all = function()
    Trace:delete({})
  end,

  star = function(params)
    local trace = Trace:one(params.id, NOT_FOUND)
    Trace:star(trace)

    h.send_json(trace)
  end,

  unstar = function(params)
    local trace = Trace:one(params.id, NOT_FOUND)
    ngx.log(0, inspect(trace))
    Trace:unstar(trace)

    h.send_json(trace)
  end,

  redo = function(params)
    local trace = Trace:one(params.id, NOT_FOUND)

    local res = Trace:redo(trace)

    h.send_json(trace)
  end,

  expire = function(params)
      local deleted = Trace:delete_expired()
      h.send_json({deleted = deleted})
  end

}

return traces
