local h   = require 'controller_helpers'
local Trace = require 'models.trace'

local function search(params, order)
  local conditions, options = h.jor_conditions_and_options(params, order)
  conditions.service_id = tonumber(params.service_id)
  return conditions, options
end

local service_traces = {

  index = function(params)
    h.send_json(Trace:all(search(params)))
  end,

  count = function(params)
    local count = Trace:count(search(params, '$gt'))
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
