local h               = require 'controller_helpers'
local inspect         = require 'inspect'
local m               = require 'model_helpers'
local fn              = require 'functional'
local shared_dict     = require 'shared_dict'
local Service         = require 'models.service'
local MiddlewareSpec  = require 'models.middleware_spec'
local Event           = require 'models.event'
local Dashboard       = require 'models.dashboard'
local Pipeline        = require 'models.pipeline'
local Brain           = require 'brain'

local has_valid_endpoint_characters = function(endpoint)
-- allowed are lowercase letters, alphanuberic characters and a dash
  return not endpoint.code:find('[^%l%w-]')
end

local has_service_already = function(endpoint)
  return not not Service:find_by_endpoint_code(endpoint.code)
end

local validate = function(service, opts)
  opts = opts or {}
  if opts.strict == false and not service.endpoints then
    service.endpoints = {}
  end

  return fn.all(has_valid_endpoint_characters, service.endpoints)
end

local services = {
  show = function(params)
    local service = Service:find_or_error(params.id)
    h.send_json(service)
  end,

  index = function(params)
    h.send_json(Service:all())
  end,

  create = function(params)
    local request = h.request_json()

    if not validate(request) then
      h.send_json({msg = 'Invalid Service attributes'}, 422)
      ngx.exit(422)
      return
    end

    if fn.any(has_service_already, request.endpoints or {}) then
      h.send_json({msg = 'There is already one service with the requested endpoint(s)'}, 422)
      ngx.exit(422)
      return
    end

    local service = Service:create(h.request_json())

    MiddlewareSpec:ensure_defaults_exist()
    local mw_spec = MiddlewareSpec:find_or_error({name = 'Set Accept-Encoding = identity'})

    m.create("pipelines", {
      service_id = service._id,
      middlewares = {
        [mw_spec._id] =  {
          name         = mw_spec.name,
          position     = 0,
          active       = true,
          description  = mw_spec.description,
          spec_id      = mw_spec._id,
          code         = mw_spec.code,
          uuid         = mw_spec._id,
          config       = {}
        }
      }
    })

    Event:create({channel = "syslog", level = "info",
                   msg = "Service " .. service._id .. " created."   })
    Event:create({channel = "syslog", level = "info",
                  msg = "Pipeline for service " .. service._id .. " (" .. service.name .. ") created."   })

    Brain.async_trigger_report()

    h.send_json(service, ngx.HTTP_CREATED)
  end,

  update = function(params)
    if not validate(h.request_json(), {strict = false}) then
      h.exit_json({msg = 'Invalid Service attributes'}, 422)
    end

    local service = Service:update(params.id, h.request_json())
    Event:create({channel = "syslog", level = "info",
                  msg = "Service " .. service._id .. " updated."   })
    h.send_json(service)
  end,

  delete = function(params)
    Service:delete_or_error(params.id, 'service not found')
    Dashboard:delete( {service_id = tonumber(params.id)})
    Pipeline:delete( {service_id = tonumber(params.id)})
    Brain.async_trigger_report()

    -- Event:create({channel = "syslog", level = "info",
    --               msg = "Service " .. params.id .. " updated."   })
  end
}



return services
