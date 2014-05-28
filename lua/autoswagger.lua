-- This file transforms the swagger hosts into / from brainslug models, stored in jor
local autoswagger_lib = require 'autoswagger.init'
local ModelHost       = require 'models.autoswagger_host'
local LibHost         = autoswagger_lib.Host


local autoswagger = {}

local function persist_host(host)
  local host_tbl = host:to_table()
  local existing = ModelHost:find({hostname = host.hostname})
  if existing then host_tbl._id = existing._id end

  ModelHost:async_save(host_tbl)
end

local function remove_header_params_from(swagger)
  for _,api in ipairs(swagger.apis or {}) do
    for _,operation in ipairs(api.operations or {}) do
      local clean_params, len = {}, 0
      for _,param in ipairs(operation.parameters or {}) do
        if param.paramType ~= 'header' then
          len = len + 1
          clean_params[len] = param
        end
      end
      operation.parameters = clean_params
    end
  end
  return swagger
end

local function get_or_create_host(service_id, endpoint)
  local host = autoswagger.get_host(service_id) --> the service id is used as the hostname
  if not host then
    -- We use the service_id as a hostname, and the endpoint as the basepath
    -- This happens because several services can share the same endpoint
    host = LibHost:new(tostring(service_id), endpoint) --> endpoint is used as the basepath
    persist_host(host)
  end
  host.base_path = endpoint or host.base_path -- always update to the latest endpoint
  return host
end

------------------------------------------

function autoswagger.get_host(service_id)
  local host_tbl = ModelHost:find({hostname = tostring(service_id)})
  if host_tbl then
    return LibHost:new_from_table(host_tbl)
  end
  -- else return nil
end

function autoswagger.get_swagger(service_id)
  local host = get_or_create_host(service_id)
  local spec = remove_header_params_from(host:to_swagger())

  -- overrride the hostname (where we are storing a service_id) with the basePath (where we store the last endpoint used)
  spec.hostname  = spec.basePath
  return spec
end

function autoswagger.learn(method, service_id, endpoint, path, args, body, header)
  local host = get_or_create_host(service_id, endpoint)
  local path = host:learn(method, path, args, body, header)
  persist_host(host)
  return path
end

return autoswagger

