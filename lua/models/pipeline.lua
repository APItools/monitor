------------
-- APItools Middleware
--
-- Middleware documentation of [APItools](https://www.apitools.com).
-- All this should be available when middleware is evaluated.
--
-- Check out our [GitHub Repository](https://github.com/apitools/monitor) and
-- [Middleware repository](https://github.com/apitools/middleware).
--
-- If you don't have enough, we have a [blog](https://docs.apitools.com/blog) and a
-- [documentation](https://docs.apitools.com/docs).
--
-- @module middleware
-- @license MIT
-- @copyright APItools 2014


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
local lxp          = require 'lxp'
local http_ng      = require 'http_ng'
local async_resty  = require 'http_ng.backend.async_resty'

local Pipeline = Model:new()
Pipeline.collection = 'pipelines'
Pipeline.excluded_fields_to_index = Model.build_excluded_fields('name', 'middlewares')

--- HTTP Client
-- Check @{http.get} for details.
-- @http http
-- @see http.get
-- @see http.put
-- @see http.post
-- @see http.patch

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

local log = function(...) ngx.log(0, inspect(...)) end

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
    --- store integer values as simple count
    -- @param[type=string] metric name
    -- @param[type=int,opt=1] increment
    -- @function metric.count
    count = function(name, inc)
      collector.collect(trace.service_id, name, 'count', { trace.req.method, trace.generic_path } , inc or 1)
    end,
    --- store integer values as set
    -- then you can get avg,p99 and other statistic
    -- @param[type=string] metric name
    -- @param[type=number] value
    -- @function metric.set
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

  --- @{Console} for all the available methods. Almost like in the browser.
  -- @console console
  local console           = Console.new(service_id, middleware.uuid)

  local middleware_bucket = Bucket.for_middleware(service_id, middleware.uuid)
  local service_bucket    = Bucket.for_service(service_id)

  local base64 = {
    --- Decodes the str argument as a base64 digest to the raw form.
    -- Returns nil if str is not well formed.
    -- @tparam string str base64 encoded string
    -- @treturn ?string decoded string
    -- @function base64.decode
    decode = ngx.decode_base64,

    --- Encode str to a base64 digest.
    -- @tparam string str a string
    -- @treturn string base64 encoded string
    -- @function base64.encode
    encode = ngx.encode_base64
  }
  local send   = {
    ---  Send email
    -- @param[type=string] to email address of the receiver
    -- @tparam string subject email subject
    -- @tparam string msg the email body
    -- @function send.email
    email = send_email,
    mail = send_email,

    ---  Create @{Event}
    -- @param[type=table] event the event to be created
    -- @function send.event
    event = send_event,

    ---  Create middleware notification
    -- Creates @{Event} and will be overriden to middleware channel.
    -- @param[type=table] event the event to be created
    -- @function send.notification
    notification = send_notification
  }
  local time   = {
    --- Current time in seconds
    -- Returns the elapsed seconds from the epoch.
    -- @treturn int elapsed seconds from the epoch
    -- @function time.seconds
    seconds = ngx.time,
    --- Formats number of seconds to a HTTP-date string
    -- Returns a formated string in "HTTP-date" format specified by the [RFC 7231](http://tools.ietf.org/html/rfc7231).
    -- It is used for example in Last-Modified header and looks like "`Tue, 15 Nov 2014 08:12:31 GMT`".
    -- @treturn string  HTTP-date formatted string
    -- @tparam int sec timestamp in seconds (like those returned from time.seconds)
    -- @function time.http
    http = ngx.http_time,
    --- Returns a floating-point number for the elapsed time in seconds
    -- (including milliseconds as the decimal part) from the epoch for the current time stamp.
    -- @treturn float elapsed seconds from the epoch (including miliseconds)
    -- @function time.now
    now = ngx.now
  }

  local bucket = {
    --- Middleware Bucket
    -- Every middleware has own bucket. You can access it by using methods of @{Bucket} methods as @{bucket.middleware}.
    -- @bucket[type=Bucket] bucket.middleware
    -- @see Bucket.get
    -- @usage local cached = bucket.middleware.get('my-cached-value')
    middleware = middleware_bucket,
    --- Service Bucket
    -- Every service has own bucket. All middlewares can access it by using @{Bucket} methods as @{bucket.service}.
    -- @bucket bucket.service
    -- @usage local cached = bucket.service.get('my-cached-value')
    -- @see Bucket.get
    service = service_bucket
  }

  local json = {
    --- JSON Encode table to a JSON string.
    -- @param[type=table] object to be serialized
    -- @return[type=string] JSON string
    -- @function json.encode
    encode = luajson.encode,
    --- Decode JSON string to an object.
    -- @param[type=string] string to be deserialized
    -- @return[type=table] deserialized object
    -- @function json.decode
    decode = luajson.decode
  }

  local xml = { new = lxp.new }

  local hmac_sha256 = function(str, key)
    local resty_hmac   = require 'resty.hmac'
    local hmac = resty_hmac:new()
    local digest = hmac:digest('sha256', tostring(key), tostring(str))
    return digest
  end

  local hmac = {
    --- Create keyed-hash message authentication code using HMAC-SHA-256.
    -- @param[type=string] str string to be signed
    -- @param[type=string] key to sign it with
    -- @return[type=string] digest
    -- @function hmac.sha256
    sha256 = hmac_sha256
  }

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
    --- @{Trace} object of current request.
    -- After all the middleware finish, it will be persisted for later search.
    -- @see Trace.req
    -- @see Trace.res
    -- @usage trace.my_middleware = 'some metadata'
    -- @usage trace.res.processed = true
    -- @table[type=Trace] trace
    trace             = trace,
    json              = json,
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
