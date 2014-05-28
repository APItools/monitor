local h      = require 'controller_helpers'
local Bucket = require 'bucket'

local service_buckets = {

  show = function(params)
    local service_id = params.service_id
    local bucket     = Bucket.for_service(service_id)
    h.send_json(bucket.get_keys())
  end,

  delete = function(params)
    local service_id = params.service_id
    local bucket     = Bucket.for_service(service_id)
    bucket.delete_all()
    h.send_json({status = 'ok'})
  end

}

return service_buckets
