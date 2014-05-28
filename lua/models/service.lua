local Model = require 'model'
local Service =  Model:new()

-- Class methods

Service.collection               = 'services'
Service.excluded_fields_to_index = Model.build_excluded_fields('description')

function Service:find_by_endpoint_code(code)
  local service = Service:find( { endpoints = {{ code = code }}})
  if service then
    for _,endpoint in ipairs(service.endpoints) do
       return service, endpoint.url
    end
  end
end

return Service
