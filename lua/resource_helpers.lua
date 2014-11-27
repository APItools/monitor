local model_helpers  = require 'model_helpers'
local helpers        = require 'controller_helpers'
local Event          = require 'models.event'

local resource_helpers = {}

resource_helpers.index = function(resource, params)
  params.stream = true
  local conditions, options = helpers.jor_conditions_and_options(params)
  helpers.send_json(model_helpers.all(resource, conditions, options))
end

resource_helpers.show = function(resource, params)
  local obj = model_helpers.find_or_error(resource, params.id, resource .. " not found")
  helpers.send_json(obj)
end

resource_helpers.count = function(resource, params)
  local conditions, options = helpers.jor_conditions_and_options(params, '$gt')
  local count = model_helpers.count(resource, conditions, options)
  helpers.send_json({document_count = count})
end

resource_helpers.create = function(resource, params)
  local obj = model_helpers.create(resource, helpers.request_json())
  Event:create({channel = "syslog", level = "info",
                 msg =  resource .. ' ' .. obj._id .. " created."   })
  helpers.send_json(obj, ngx.HTTP_CREATED)
end

resource_helpers.update = function(resource, params)
  local obj = model_helpers.update(resource, params.id, helpers.request_json())
  Event:create({channel = "syslog", level = "info",
                msg = resource .. ' ' .. obj._id .. " updated."   })
  helpers.send_json(obj)
end

resource_helpers.delete = function(resource, params)
  model_helpers.delete_or_error(resource,  params.id)
end

return resource_helpers
