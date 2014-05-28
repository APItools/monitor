local h       = require 'controller_helpers'
local m       = require 'model_helpers'
local slug    = require 'middlewares.brainslug'
local tracer  = require 'middlewares.tracer'
local Pipeline = require 'models.pipeline'


local Event   = require 'models.event'

-- { _id,
--   service_id,
--   middlewares = [
--     { name = 'brainslug', -- brainslug middleware is special and only needs name & position. It is always active
--       position = 0 -- can be moved
--     },
--     { name = "string"
--       position = 1,
--       active = true, -- false deactivates the middleware. Defaults to true if not present!
--       description = "an informative string",
--       spec_id = 28, -- optional
--       code = "return function(req, res, ...) <do something with req and res> end",
--       config = {}, -- optional, JSON object. It gets codified and inserted on the ... part of the function
--     }, ...
--   ]
-- }

local pipelines = {
  -- /api/service/:service_id/pipeline
  update = function(params)
    local pipeline = Pipeline:update_with_versioning(
      { service_id = tonumber(params.service_id) },
      h.request_json()
    )
    Event:create({channel = "syslog", level = "info",
                  msg = "Pipeline " .. pipeline._id .. " updated."   })

    h.send_json(pipeline)
  end,

  show = function(params)
    local inspect = require 'inspect'
    local pipeline = Pipeline:find_or_error({ service_id = tonumber(params.service_id)})
    h.send_json(pipeline)
  end,

  -- for testing purposes only
  index = function(params)
    local pipelines = Pipeline:all({})
    h.send_json(pipelines)
  end


}

return pipelines
