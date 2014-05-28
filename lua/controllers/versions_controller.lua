local h   = require 'controller_helpers'
local m   = require 'model_helpers'

local versions = {

  pipelines = function(params)
    h.send_json(m.all("versions", {
      collection = "pipelines",
      object = {
        service_id = tonumber(params.service_id)
      }
    }))
  end,

  index = function(params)
    h.send_json(m.all("versions", {}))
  end,

  show = function(params)
    local version = m.find_or_error("versions", params.id, "version not found")
    h.send_json(version)
  end,

  delete = function(params)
    m.delete_or_error("versions",  params.id)
  end,
}

return versions
