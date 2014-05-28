local h      = require 'controller_helpers'
local Bucket = require 'bucket'

local middleware_buckets = {

  index = function(params)
    local service_id = tonumber(params.service_id)

    local pipeline = m.find('pipelines', {service_id = service_id})

    local middlewares = {}
    if pipeline then
      for _,mw in pairs(pipeline.middlewares) do
        local bucket = Bucket.for_middleware(service_id, mw.uuid)
        middlewares[mw.uuid] = bucket.get_keys()
      end
    end

    h.send_json(middlewares)
  end,

  delete = function(params)
    local service_id = params.service_id
    local uuid       = params.uuid
    local bucket     = Bucket.for_middleware(service_id, uuid)

    bucket.delete_all()
    h.send_json({status = 'ok'})
  end

}

return middleware_buckets
