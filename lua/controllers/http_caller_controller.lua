local ngxex     = require 'ngxex'
local http      = require 'http'
local h         = require 'controller_helpers'
local inspect   = require 'inspect'
local m         = require 'model_helpers'
local services  = require 'controllers.services_controller'

local http_caller = {}

http_caller.do_call = function(params)
  local method = params.method
  local args = params.args
  local body = params.body

  local service = m.find_or_error("services", params.service_id)

  local url = "http://127.0.0.1:10002" .. params.url
  local host = ngx.var.host
  local endpoint = service.endpoints[1].code .. "-" .. host

  local query = {
    method = method,
    url = url,
    headers = { Host = endpoint ,
								['User-Agent'] = 'apitools'}
  }
  local body, status, headers = http.simple(query, ngxex.req_get_all_body_data())

  ngx.status = status
  -- for name, value in pairs(headers) do
  --  ngx.header[name] = value
  -- end
  ngx.print(body)
end


return http_caller
