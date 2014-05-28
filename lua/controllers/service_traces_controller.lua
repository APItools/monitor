local h   = require 'controller_helpers'
local m   = require 'model_helpers'
local Event = require 'models.event'
local Trace = require 'models.trace'
local fn = require 'functional'

local map = fn.map

local inspect = require 'inspect'

local function search(params)
  local conditions, options = h.jor_conditions_and_options(params)
  conditions.service_id = tonumber(params.service_id)
  return conditions, options
end

local service_traces = {

  count = function(params)
    local conditions, options = h.jor_conditions_and_options(params, '$gt')
    conditions.service_id = tonumber(params.service_id)
    local count = Trace:count(conditions, options)
    h.send_json({document_count = count})
  end,

  search = function(params)
    h.send_json(Trace:all(search(params)))
  end,

  search_for_index = function(params)
    h.send_json(Trace:for_index(search(params)))
  end,

  delete_all = function(params)
    Trace:delete({service_id = tonumber(params.service_id)})
  end
}

return service_traces
