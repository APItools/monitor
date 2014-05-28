local inspect         = require 'inspect'
local autoswagger     = require 'autoswagger'
local collector       = require 'collector'
local Service         = require 'models.service'
local statsd          = require 'statsd_wrapper'

local function get_endpoint_host()
  return string.match(ngx.var._endpoint_url, "^.+://([^/]+)")
end

local pass_response = function(req, res, endpoint_url)
  local start    = ngx.now()

  -- override original request body with middelware's version
  -- TODO: if req.body= would set the request body, we would not have to do it here
  if req.body then
    ngx.req.set_body_data(req.body)
    req.headers['Content-Length'] = #req.body
  end

  -- nginx is unable to resolve private names like localhost.  We
  -- hardcode the resolution of localhost to 127.0.0.0 for now,
  -- and remove trailing slash
  ngx.var._endpoint_url  = endpoint_url:gsub('localhost', '127.0.0.1', 1):gsub('/$', '')
  ngx.var._endpoint_host = get_endpoint_host()

  ngx.var._path = req.uri or '/'

  local response_data = ngx.location.capture("/___pass", {
    method         = ngx["HTTP_" .. req.method],
    args           = req.args,
    ctx = { headers = req.headers },
    always_forward_body = true,
    copy_all_vars = true
  })

  local elapsed_time = ngx.now() - start

  statsd.time('proxy.real_request', elapsed_time)

  res.status = response_data.status
  res.body = response_data.body

  for k,v in pairs(response_data.header) do
    res.headers[k] = v
  end

  return elapsed_time
end

local function get_generic_path(req, service_id, status)
  -- if successful request, we must build the swagger spec
  local generic_path = nil
  if status >= 200 and status < 300 then
    local service = Service:find(service_id)
    if not service then
      generic_path =  "not available (service not found)"
    else
      local endpoint_url = service.endpoints[1].url
      if endpoint_url == '*' then
        generic_path = "not available (services url is '*')"
      else
        generic_path = autoswagger.learn(req.method, service_id, req.host, req.uri, req.args, req.body, req.headers)
        generic_path = generic_path or "not available"
      end
    end
  end

  return generic_path
end

local function collect_metrics(service_id, method, status, time, generic_path)
  local start = ngx.now()
  collector.collect(service_id, 'hits',   'count', {method, generic_path},         1)
  collector.collect(service_id, 'status', 'count', {method, generic_path, status}, 1)
  collector.collect(service_id, 'time',   'set',   {method, generic_path},         time)
  statsd.time('proxy.brainslug_mw.collect', ngx.now() - start)
end

local function fill_trace_with_req(trace, req)
  trace.req.headers = req.headers
  trace.req.body = req.body
end

-- return the middleware
return function(req, next_middleware, config)
  local start        = ngx.now()
  local trace        = config.trace
  local endpoint_url = config.endpoint_url
  local service_id   = tonumber(config.service_id)

  fill_trace_with_req(trace, req)

  assert(type(trace) == "table", "Trace expected in brainslug")

  local res = next_middleware()

  trace.time          = pass_response(req, res, endpoint_url)
  trace.generic_path  = get_generic_path(req, service_id, res.status)
  trace.endpoint      = assert(get_endpoint_host(), "Endpoint host expected")

  -- Feel free to refactor this one, but we needed to show full original url in the UI
  trace.req.endpoint = ngx.var._endpoint_url

  collect_metrics(service_id, req.method, res.status, trace.time, trace.generic_path or req.uri)

  statsd.time('proxy.brainslug_mw.total', ngx.now() - start)

  return res
end
