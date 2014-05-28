local h   = require 'controller_helpers'
local m   = require 'model_helpers'

return {
  show = function(params)
    local pipeline = m.find('pipelines', { middlewares = {[params.uuid] = {uuid = params.uuid}} })
    if pipeline then
      h.send_json(pipeline.middlewares[params.uuid])
    else
      error({status = 404, message = 'middleware not found'})
    end
  end
}
