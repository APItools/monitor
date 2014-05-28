
-- defined in global variable for now
local autoswagger  = require 'autoswagger'
local h            = require 'controller_helpers'
local Service      = require 'models.service'

local function get_host_from_service_id_or_error(service_id)
  if not service_id then error({message = "Must provide a service id", status = 400}) end

  service_id = tostring(service_id)

  local service = Service:find_or_error(service_id)

  local host = autoswagger.get_host(service._id)
  if not host then error({message = "Host for service " .. service_id .. " not found", status = 404}) end

  return host
end

local docs = {}

docs.show = function(params)
    local service_id = params.service_id
    local service = Service:find_or_error(service_id)
    local spec = autoswagger.get_swagger(service._id)

    return h.send_json(spec)
  end

docs.download = function(params)
    local file = "docs_" .. params.service_id .. ".json"
    ngx.header['Content-Disposition'] = "attachment; filename=" .. file
    return docs.show(params)
  end

docs.get_path_autocomplete = function(params)
    local query    = params.query or ""
    local host     = get_host_from_service_id_or_error(params.service_id)
    local response = h.empty_json_array()

    local matching_apis = host:find_apis_by_subpath(query)
    for _, api in pairs(matching_apis) do
      response[#response + 1] = {
        path    = api.path,
        methods = api:get_methods()
      }
    end

    h.send_json(response)
  end

docs.get_operation = function(params)
    local path    = tostring(params.path or "")
    local method  = string.upper(params.method or "GET")
    local host    = get_host_from_service_id_or_error(params.service_id)

    local api = host:find_api_by_equivalent_path(path)
    if not api then error({message = "Could not find equivalent api for path " .. path, status = 404}) end

    local operation = api.operations[method]
    if not operation then error({message = "Operation not found for method " .. method .. " on path " .. api.path, status = 404}) end

    h.send_json(operation:to_swagger())
  end

docs.get_used_methods = function(params)
    local host     = get_host_from_service_id_or_error(params.service_id)

    local methods_hash = {}

    for _,api in pairs(host.apis) do
      for method,_ in pairs(api.operations) do
        methods_hash[method] = true
      end
    end

    local methods_array = h.empty_json_array()
    for method,_ in pairs(methods_hash) do
      methods_array[#methods_array + 1] = method
    end

    return h.send_json({methods = methods_array})
  end

return docs
