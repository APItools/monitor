------------
-- @module middleware

--- options
-- @type HTTP

--- Options that can be passed to @{http} calls.
-- @table options
-- @field[type=table] headers table of HTTP headers
-- @field[type=table] ssl table with ssl options
-- @usage http.get(uri, { ssl = { verify = false }})
-- @usage http.get(uri, { headers = { my_header = 'value' }})

local headers = require 'http_ng.headers'
local request = { headers = headers }

function request.extract_headers(req)
  local options = req.options or {}
  local headers = request.headers.new(options.headers)

  headers.user_agent = headers.user_agent or 'APItools (+https://www.apitools.com)'
  headers.host = headers.host or string.match(req.url, "^.+://([^/]+)")
  headers.connection = headers.connection or 'Keep-Alive'

  options.headers = nil

  return headers
end

function request.new(req)
  assert(req)
  assert(req.url)
  assert(req.method)

  req.options = req.options or {}
  req.client = req.client or {}

  req.headers = request.extract_headers(req)
  req.options.ssl = req.options.ssl or { verify = true }

  setmetatable(req, {
    __index =  {
      serialize = req.serializer or function() end
    }
  })

  req.serialize(req)

  return req
end

return request
