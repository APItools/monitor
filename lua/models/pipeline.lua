local inspect      = require 'inspect'
local rack_module  = require 'rack'
local sandbox      = require 'sandbox'
local Trace        = require 'models.trace'
local Event        = require 'models.event'
local http_mw      = require 'http_mw'
local luajson      = require 'json'
local brainslug    = require 'middlewares.brainslug'
local statsd       = require 'statsd_wrapper'
local sanitizer    = require 'middlewares.sanitizer'
local collector    = require 'collector'
local Console      = require 'console'
local Bucket       = require 'bucket'
local Model        = require 'model'
local xml          = require 'lxp'
local http_ng      = require 'http_ng'
local async_resty  = require 'http_ng.backend.async_resty'

local Pipeline = Model:new()
Pipeline.collection = 'pipelines'
Pipeline.excluded_fields_to_index = Model.build_excluded_fields('name', 'middlewares')

local http = http_ng.new{ backend = async_resty,
                          simple = http_mw.simple, multi = http_mw.multi }

-- { _id,
--   service_id,
--   middlewares = [
--     { name = 'brainslug', -- brainslug middleware is special and only needs name & position. It is always active
--       position = 0 -- can be moved
--     },
--     { name = "string"
--       position = 1,
--       active = true, -- false deactivates the middleware. Defaults to true if not present!
--       description = "an informative string",
--       spec_id = 28, -- optional
--       code = "return function(req, res, ...) <do something with req and res> end",
--       config = {}, -- optional, JSON object. It gets codified and inserted on the ... part of the function
--     }, ...
--   ]
-- }

local get_active_middlewares = function(middlewares)
  local result = {}
  for _,middleware in pairs(middlewares) do
    if middleware.active ~= false then
      result[#result + 1] = middleware
    end
  end
  return result
end

local sort_by_position = function(a,b) return a.position < b.position end

local get_active_sorted_middlewares = function(pipeline)
  local result = get_active_middlewares(pipeline.middlewares)
  table.sort(result, sort_by_position)
  return result
end

local send_event = function(ev) Event:create(ev) end
local send_notification = function(ev) ev.channel = 'middleware' Event:create(ev) end

local log = function(x) ngx.log(0, inspect(x)) end

local send_email = function(to, subject, msg)
  assert(to); assert(subject); assert(msg)
  Event:create({
    channel  = "events:mailer",
    level    = "info",
    to       = to,
    msg      = msg,
    body     = msg,
    subject  = subject,
    read     = true
  })
end

local metric = function(trace)

  return {
    count = function(name, inc)
      collector.collect(trace.service_id, name, 'count', { trace.req.method, trace.generic_path } , inc or 1)
    end,
    set = function(name, value)
      collector.collect(trace.service_id, name, 'set', { trace.req.method, trace.generic_path } , value)
    end
  }
end

local use_middleware = function(rack, middleware, trace, service_id)
  local config      = middleware.config or {}
  local chunk, err  = loadstring(middleware.code, middleware.name or '')

  if not chunk then
    Console.new(service_id, middleware.uuid).error("Error parsing middleware: "  .. err)
    error(err)
  end

  local console           = Console.new(service_id, middleware.uuid)
  local middleware_bucket = Bucket.for_middleware(service_id, middleware.uuid)
  local service_bucket    = Bucket.for_service(service_id)

  local base64 = { decode = ngx.decode_base64, encode = ngx.encode_base64 }
  local send =   { email = send_email, mail = send_email, event = send_event, notification = send_notification }
  local time =   { seconds = ngx.time, http = ngx.http_time, now = ngx.now }
  local bucket = { middleware = middleware_bucket, service = service_bucket }

  local hmac_sha256 = function(str, key)
    local resty_hmac   = require 'resty.hmac'
    local hmac = resty_hmac:new()
    local digest = hmac:digest('sha256', tostring(key), tostring(str))
    return digest
  end

  local hmac = { sha256 = hmac_sha256 }

  local env  = {
    console           = console,
    inspect           = inspect,

    -- just ngx.log
    log               = log,
    base64            = base64,
    hmac              = hmac,
    http              = http,
    bucket            = bucket,
    send              = send,
    time              = time,
    metric            = metric(trace),
    trace             = trace,
    json              = luajson,
    xml               = xml
  }

  -- FIXME quota has to be deactivated until we can run the middlewares as coroutines
  local returned_middleware_f  = sandbox.run(chunk, {env=env, quota = false})
  local sandboxed_middleware_f = sandbox.protect(returned_middleware_f, {env = env, quota = false})

  rack:use(sandboxed_middleware_f, config)
end

function Pipeline:get(service)
  Model:check_dots(self, Pipeline, 'get')
  return self:find({ service_id = service._id })
end

Pipeline.execute = function(pipeline, endpoint_url)

  local start_time = ngx.now()

  local rack       = rack_module.new()
  local req        = rack:create_initial_request()
  _ = req.body -- force the reading of the request body

  local trace      = Trace:new(req)

  trace.service_id = pipeline.service_id

  rack:use(sanitizer, {
    endpoint = string.match(endpoint_url, "://([^/]+)")
  })

  local ok, res = pcall(function()
    for _,middleware in ipairs(get_active_sorted_middlewares(pipeline)) do
      use_middleware(rack, middleware, trace, pipeline.service_id)
    end

    rack:use(brainslug, {
      trace         = trace,
      service_id    = pipeline.service_id,
      endpoint_url  = endpoint_url
    })

    return rack:run(req)
  end)

  Trace:async_save(trace, function()
    if ok then
      rack:respond(res)
      statsd.time('proxy.pipeline.execute', ngx.now() - start_time)

      -- continue in async fashion and save the trace on background
      Trace:setRes(trace, res)
    else
      -- an error was thrown while processing the request. The user will not
      -- receive the result. The trace will be saved with an "error" status,
      -- and the error will be written in the log
      Trace:setError(trace, res)
      error(res)
    end
  end)
end


return Pipeline
