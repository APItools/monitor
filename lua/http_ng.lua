------------
--- HTTP
-- HTTP client
-- @module middleware

--- HTTP
-- @type HTTP

local resty_backend = require 'http_ng.backend.resty'
local json = require 'cjson'
local request = require 'http_ng.request'
local http = { request = request }


http.method = function(method, client)
  assert(method)
  assert(client)

  return function(url, options)
    if type(url) == 'table' and not options then
      options = url
      url = unpack(url)
    end

    assert(url, 'url as first parameter is required')

    local req = http.request.new({
      url         = url,
      method      = method,
      options     = options,
      client      = client,
      serializer  = client.serializer or http.serializers.default
    })
    return client.backend.send(req)
  end
end

http.method_with_body = function(method, client)
  assert(method)
  assert(client)

  return function(url, body, options)
    if type(url) == 'table' and not body and not options then
      options = url
      url, body = unpack(url)
    end

    assert(url, 'url as first parameter is required')
    assert(body, 'body as second parameter is required')

    local req = http.request.new{ url = url, method = method, body = body,
                                  options = options, client = client,
                                  serializer = client.serializer or http.serializers.default  }
    return client.backend.send(req)
  end
end

--- Make GET request.
-- @param[type=string] url
-- @param[type=options] options
-- @return[type=response] a response
-- @function http.get
http.get = http.method

--- Make HEAD request.
-- @param[type=string] url
-- @param[type=options] options
-- @return[type=response] a response
-- @function http.head
http.head = http.method

--- Make DELETE request.
-- @param[type=string] url
-- @param[type=options] options
-- @return[type=response] a response
-- @function http.delete
http.delete = http.method

--- Make OPTIONS request.
-- @param[type=string] url
-- @param[type=options] options
-- @return[type=response] a response
-- @function http.options
http.options = http.method

--- Make PUT request.
-- The **body** is serialized by @{HTTP.urlencoded} unless you used different serializer.
-- @param[type=string] url
-- @param[type=string|table] body
-- @param[type=options] options
-- @return[type=response] a response
-- @function http.put
http.put = http.method_with_body

--- Make POST request.
-- The **body** is serialized by @{HTTP.urlencoded} unless you used different serializer.
-- @param[type=string] url
-- @param[type=string|table] body
-- @param[type=options] options
-- @return[type=response] a response
-- @function http.post
http.post = http.method_with_body

--- Make PATCH request.
-- The **body** is serialized by @{HTTP.urlencoded} unless you used different serializer.
-- @param[type=string] url
-- @param[type=string|table] body
-- @param[type=options] options
-- @return[type=response] a response
-- @function http.patch
http.patch = http.method_with_body

http.trace = http.method_with_body

http.serializers = {}

--- Urlencoded serializer
-- Serializes your data to `application/x-www-form-urlencoded` format
-- and sets correct Content-Type header.
-- @http HTTP.urlencoded
-- @usage http.urlencoded.post(url, { example = 'table' })
http.serializers.urlencoded = function(req)
  req.body = ngx.encode_args(req.body)
  req.headers.content_type = req.headers.content_type or 'application/x-www-form-urlencoded'
  http.serializers.string(req)
end

http.serializers.string = function(req)
  req.body = tostring(req.body)
  req.headers['Content-Length'] = #req.body
end

--- JSON serializer
-- Converts the body to JSON unless it is already a string
-- and sets correct Content-Type `application/json`.
-- @http HTTP.json
-- @usage http.json.post(url, { example = 'table' })
-- @see http.post
http.serializers.json = function(req)
  if type(req.body) ~= 'string' then
    req.body = json.encode(req.body)
  end
  req.headers.content_type = req.headers.content_type or 'application/json'
  http.serializers.string(req)
end

http.serializers.default = function(req)
  if req.body then
    if type(req.body) ~= 'string' then
      http.serializers.urlencoded(req)
    else
      http.serializers.string(req)
    end
  end
end

local function add_http_method(client, method)
  local generator = http[method:lower()]

  if generator then
    local func = generator(method:upper(), client)
    rawset(client, method, func)
    return func
  end
end

local function chain_serializer(client, format)
  local serializer = http.serializers[format]

  if serializer then
    return http.new{ backend = client.backend, serializer = serializer }
  end
end

local function generate_client_method(client, method_or_format)
  return add_http_method(client, method_or_format) or chain_serializer(client, method_or_format)
end

function http.new(client)
  client = client or { }
  client.backend = client.backend or resty_backend

  return setmetatable(client, { __index  = generate_client_method  })
end

return http
