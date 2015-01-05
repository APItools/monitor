------------
--- Rack
-- Lua Rack. Processes middleware pipeline.
-- @module middleware

local rack = {
  _VERSION     = 'lua-resty-rack 0.3',
  _DESCRIPTION = 'rack for openresty',
  _URL         = 'https://github.com/APItools/lua-resty-rack',
  _LICENSE     = [[
    2-clause BSD-LICENSE

    This module is licensed under the 2-clause BSD license.

    * Copyright (c) 2012, James Hurst (james@pintsized.co.uk)
    * Copyright (c) 2013, Raimon Grau (raimonster@gmail.com)
    * Copyright (c) 2013, Enrique García (kikito@gmail.com)

    All rights reserved.

    Redistribution and use in source and binary forms, with or without modification,
    are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation and/or
      other materials provided with the distribution.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
    AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
    WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
    IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
    INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
    DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
    LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
    OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
    OF THE POSSIBILITY OF SUCH DAMAGE.
  ]]
}

local function rack_assert(condition, message)
  if not condition then
    ngx.log(ngx.ERR, message)
    ngx.exit(500)
  end
end

local function check_response(status, body)
  rack_assert(status, "Rack returned with no status. Ensure that you set res.status to something in at least one of your middlewares.")
end

local function copy(src, dest)
  dest = dest or {}
  for k,v in pairs(src) do dest[k] = v end
  return dest
end

local function normalize(str)
  return str:gsub("_", "-"):lower():gsub("^%l", string.upper):gsub("-%l", string.upper)
end

-- Metatable functions that, when used as metamethods:
-- * They titleize keys, so t.foo and t.Foo return the same
-- * They replace underscores by dashes ant titleizes things, so t['Foo-Bar'] returns the same as t.foo_bar
-- Internally, the keys are stored in Titled-Names format, not in underscored_names format. This makes it easier
-- to go over the headers with a loop.
local headers_index    = function(t, k) return rawget(t, normalize(k)) end
local headers_newindex = function(t, k, v) rawset(t, normalize(k), v) end

local create_headers_mt = function()
  return { __index = headers_index, __newindex = headers_newindex }
end

local bodybuilder_index = function(t, k)
  if k == 'body' then
    local body_data = ngx.req.get_body_data() -- returns nil when no data, or too large (so it's in a file)
    if not body_data then
      local file = ngx.req.get_body_file() -- returns nil when no data, or not in file
      if file then
        local f, err = io.open(file, "r")
        rack_assert(f, 'could not read request body file: ' .. err)
        body_data = f:read("*a")
        f:close()
      end
    end

    rawset(t, 'body', body_data)
    return body_data
  end
end

--- Rack
-- @type Rack
local Rack = {}

--- Response
-- @table Rack.Response
-- @field[type=string] body
-- @field[type=int] status
-- @field[type=table] headers

local function create_initial_response()
  return {
    body     = nil,
    status   = nil,
    headers  = setmetatable({}, create_headers_mt())
  }
end
----------------- PUBLIC INTERFACE ----------------------

function Rack:use(f, ...)
  rack_assert(f, "Invalid middleware")
  self.middlewares[#(self.middlewares) + 1] = { f = f, args = {...} }
end

function Rack:run(req)
  req = req or self:create_initial_request()
  local res = create_initial_response()

  --- evaluates other middlewares and returns a response
  -- @function next_middleware
  -- @return[type=Rack.Response]

  local function next_middleware()
    local len = #(self.middlewares)
    if len == 0 then return res end

    local mw = table.remove(self.middlewares, 1)
    --- executing a middleware
    -- @function middleware
    -- @param[type=Rack.Request] request
    -- @param next_middleware @{Rack:next_middleware}
    local res = mw.f(req, next_middleware, unpack(mw.args))
    if type(res) ~= 'table' then
      error("A middleware did not return a valid response. Check that all your middlewares return a response of type 'table'")
    end
    return res
  end

  return next_middleware()
end

function Rack:respond(res)
  if not ngx.headers_sent then
    check_response(res.status, res.body)

    copy(res.headers or {}, ngx.header)
    ngx.status = res.status
    ngx.print(res.body)
    ngx.eof()
  end
end



function Rack:create_initial_request()
  local query  = ngx.var.query_string or ""
  local scheme = ngx.var.scheme
  local host   = ngx.var.host

  local uri = ngx.var.request_uri:gsub('%?.*', '')
  -- uri_relative = /test?arg=true
  local uri_relative  = uri .. ngx.var.is_args .. query
  -- uri_full = http://example.com/test?arg=true
  local uri_full      =  scheme .. '://' ..  host .. uri_relative

  local headers = copy(ngx.req.get_headers(100, true))
  setmetatable(headers, create_headers_mt())

  local bodybuilder_mt = {__index = bodybuilder_index }

  --- Request
  -- @usage
  -- return function(request, next_middleware)
  --   request.uri = '/different'
  --   return next_middleware()
  -- end
  -- @table Rack.Request
  -- @field[type=string] query
  -- @field[type=table] headers
  -- @field[type=string] method HTTP method
  -- @field[type=string] scheme http/https
  -- @field[type=string] uri_full full uri with scheme, host and query string
  -- @field[type=string] uri_relative just path
  -- @field[type=string] uri path with query string
  -- @field[type=string] host
  -- @field[type=table] args

  return setmetatable({
    query         = query,
    headers       = headers,
    uri_full      = uri_full,
    uri_relative  = uri_relative,
    args          = ngx.req.get_uri_args(),
    method        = ngx.var.request_method,
    scheme        = scheme,
    uri           = uri,
    host          = host
  }, bodybuilder_mt)
end

function rack.new()
  return setmetatable({middlewares = {}}, {__index = Rack})
end

return rack
