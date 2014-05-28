local h   = require 'controller_helpers'
local MiddlewareSpec = require 'models.middleware_spec'

return {
  index = function(params)
    MiddlewareSpec:ensure_defaults_exist()
    h.send_json(MiddlewareSpec:all())
  end,

  show = function(params)
    h.send_json(MiddlewareSpec:find(params.id))
  end,

  create = function(params)
    local attributes = h.request_json()
    local middleware_spec = MiddlewareSpec:create(attributes)

    h.send_json(middleware_spec, ngx.HTTP_CREATED)
  end,

  update = function(params)
    local middleware_spec = MiddlewareSpec:update(params.id, h.request_json())
    h.send_json(middleware_spec)
  end,

  delete = function(params)
    h.send_json(MiddlewareSpec:delete(params.id))
  end
}
