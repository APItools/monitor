------------
--- Trace
-- Trace object. Holds both request and response.
-- @module middleware

local Model    = require 'model'
local Service  = require 'models.service'
local Event    = require 'models.event'
local fn       = require 'functional'
local http     = require 'http'
local uuid4    = require 'uuid'
local inspect  = require 'inspect'
local Config   = require 'models.config'


--- Trace
-- @type Trace

local Trace = Model:new()

-- Class methods

Trace.collection               = 'traces'
Trace.excluded_fields_to_index = {res = { body = true  } }

Trace.keep = 1000

local function link(uuid)
  local slug_name = Config.get_slug_name()
  return "https://" .. slug_name .. ".my.apitools.com/app/traces/find/" .. uuid
end

local Trace_mt = {
  __index = function(table, key)
    if key == 'link' then
      return link(table.uuid)
    else
      return rawget(table, key)
    end
  end
}

function Trace:new(req)
  --- Current HTTP Request like it will be stored and displayed in the UI.
  -- @table Trace.req
  -- @field[type=string] query query string
  -- @field[type=table] headers
  -- @field[type=string] uri_full whole URI including scheme, host, port, path and query string
  -- @field[type=string] uri_relative path + query string
  -- @field[type=table] args parsed query string
  -- @field[type=string] method HTTP Method
  -- @field[type=string] scheme HTTP Scheme (http/https)
  -- @field[type=string] uri just the path
  -- @field[type=string] host value of Host header

  --- Will contain the response like it will be stored (once it is processed).
  -- @table Trace.res
  -- @field[type=string] body
  -- @field[type=int] status
  -- @field[type=table] headers

  --- time in seconds how long it took APItools to return the request
  -- @field[type=number] total_time

  --- id of the service that processed the request
  -- @field[type=number] service_id

  --- starred
  -- @field[type=boolean] starred

  Model:check_dots(self, Trace, 'new')
  local trace = { req = req, uuid = uuid4.getUUID() }
  return setmetatable(trace, Trace_mt)
end

function Trace:delete_expired(to_keep)
  Model:check_dots(self, Trace, 'delete_expired')
  local total = Trace:count({})

  if total > Trace.keep then
    self:delete({ starred = false }, { max_documents = total -  Trace.keep })
  end
end

-- Instance Methods

function Trace:setRes(trace, res)
  Model:check_dots(self, Trace, 'setRes')
  trace.starred = false
  trace.res = {
    status = res.status,
    body   = res.body,
    headers = {}
  }
  if type(res.headers) == 'table' then
    for k,v in pairs(res.headers) do trace.res.headers[k] = v end
  end
  -- record how long it took brainslug and remote server
  trace.total_time = ngx.now() - ngx.req.start_time()
  if trace.total_time and trace.time then
    trace.overhead_time = trace.total_time - trace.time
  end
end

function Trace:setError(trace, err)
  err = tostring(err)

  Model:check_dots(self, Trace, 'setError')
  trace.starred     = false

  trace.res         = trace.res         or {}
  trace.res.headers = trace.res.headers or {}
  trace.res.status  = trace.res.status  or 500
  trace.res.body    = trace.res.body    or err

  trace['error']    = err

  Event:create({
    channel  = "middleware",
    level    = "error",
    msg      = "An error happened while processing a request",
    trace    = trace,
    err      = err
  })
end

function Trace:star(trace)
  Model:check_dots(self, Trace, 'persist')
  trace.starred = true
  Trace:save(trace)
  return trace
end

function Trace:unstar(trace)
  Model:check_dots(self, Trace, 'persist')
  trace.starred = false
  Trace:save(trace)
  return trace
end

local index_attrs     = { _id = true,  _created_at = true, time = true, overhead_time = true, total_time = true,
                          service_id = true, starred = true }

local index_req_attrs = {method = true, uri = true, headers = true}
local index_res_attrs = {status = true, headers = true}

function Trace:for_index(conditions, options)
  Model:check_dots(self, Trace, 'for_index') -- Michal: this looks weird, just use dot everywhere, they are class level methods anyway
  local traces = self:all(conditions, options)

  return fn.map(function(trace)
      local clean_trace = {req = {}, res={}}
      for attr,_ in pairs(index_attrs)     do
        clean_trace[attr]     = trace[attr]
      end

      for attr,_ in pairs(index_req_attrs) do
        clean_trace.req[attr] = trace.req[attr]
      end

      for attr,_ in pairs(index_res_attrs) do
        if trace.res then --if there's no trace.res for some reason
          clean_trace.res[attr] = trace.res[attr]
        end
      end

      return clean_trace
    end, traces)
end

function Trace:redo(trace)
  local query = {
    method = trace.req.method,
    url = "http://127.0.0.1:10002" .. trace.req.uri_relative,
    headers = trace.req.headers
  }
  query.headers.Host = trace.req.host

  local service = Service:find_or_error(trace.service_id, 'service ' .. trace.service_id .. ' not found')


  return http.simple(query, trace.req.body)
end

return Trace
