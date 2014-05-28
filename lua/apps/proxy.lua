local m             = require 'model_helpers'
local error_handler = require 'error_handler'
local Pipeline      = require 'models.pipeline'
local Service       = require 'models.service'
local statsd        = require 'statsd_wrapper'

local get_service_and_user_from_host = function(host)
  return string.match(host, "^(.*)%-([^.]+)")
end

local get_user_and_service_from_proxy = function(header)
  local base64 = header:match("^Basic (.+)$")
  local credentials = ngx.decode_base64(base64)

  return credentials:match("^(.+):(.+)$")
end

local service, user
local proxy_authorization = ngx.var.http_proxy_authorization
local proxy_mode

if proxy_authorization then -- probably proxy mode
  user, service = get_user_and_service_from_proxy(proxy_authorization)
  proxy_mode = 'proxy'
end

if not user or not service then
  service, user = get_service_and_user_from_host(ngx.var.host)
  proxy_mode = 'manual'
end

local service, url = Service:find_by_endpoint_code(service)

error_handler.execute_and_report(function()
  assert(service, "no service for ".. ngx.var.host)

  local pipeline = service and Pipeline:get(service)

  assert(pipeline, "no pipeline for service ".. service._id)

  if proxy_mode == 'proxy' then -- cleanup proxy auth header
    ngx.req.clear_header('Proxy-Authorization')

    if url == '*' then
      url = "http://" .. ngx.var.http_host
    end

    url = url:gsub('localhost', '127.0.0.1', 1)
  end

  Pipeline.execute(pipeline, url)

  statsd.time('proxy.request', ngx.now() - ngx.req.start_time())
end)

ngx.exit(ngx.OK)
