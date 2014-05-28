local m        = require 'model_helpers'
local defaults = require 'models.default_middleware_specs'

-- local MiddlewareSpec = {}
-- local collection = 'middleware_specs'

local Model = require 'model'
local MiddlewareSpec = Model:new()

MiddlewareSpec.collection = 'middleware_specs'
MiddlewareSpec.excluded_fiels_to_index = Model.build_excluded_fields('description', 'code')

function MiddlewareSpec:ensure_defaults_exist()
  for i = 1, #defaults do
    if not MiddlewareSpec:find({name = defaults[i].name}) then
      MiddlewareSpec:create(defaults[i])
    end
  end
end

function MiddlewareSpec:create(attrs)
  local middleware_spec = Model.create(self, attrs)
  local middleware_id = attrs.middleware_id

  if middleware_id then -- update the middleware's spec_id to point to new spec
    local condition = { middlewares = {[middleware_id] = {uuid = middleware_id}} }
    local update = { middlewares = {[middleware_id] = { spec_id = middleware_spec._id } } }

    local pipeline, err = m.update('pipelines', condition, update)
  end

  return middleware_spec
end

return MiddlewareSpec
