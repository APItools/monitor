local backend = require 'http_ng.backend.resty'
local json = require 'cjson'
local request = require 'http_ng.request'
local http = { request = request }

http.method = function(method, client)
  assert(method)
  assert(client)

  return function(url, options)
    assert(url, 'url as first parameter is required')

    local req = http.request.new{ url = url, method = method,
                                  options = options, client = client,
                                  serializer = client.serializer or http.serializers.default }
    return client.backend.send(req)
  end
end

http.method_with_body = function(method, client)
  assert(method)
  assert(client)

  return function(url, body, options)
    assert(url, 'url as first parameter is required')
    assert(body, 'body as second parameter is required')

    local req = http.request.new{ url = url, method = method, body = body,
                                  options = options, client = client,
                                  serializer = client.serializer or http.serializers.default  }
    return client.backend.send(req)
  end
end

http.get = http.method
http.head = http.method
http.put = http.method_with_body
http.post = http.method_with_body
http.delete = http.method
http.options = http.method
http.patch = http.method_with_body
http.trace = http.method_with_body

http.serializers = {}

http.serializers.urlencoded = function(req)
  req.body = ngx.encode_args(req.body)
  req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
  http.serializers.string(req)
end

http.serializers.string = function(req)
  req.body = tostring(req.body)
  req.headers['Content-Length'] = #req.body
end

http.serializers.json = function(req)
  if type(req.body) ~= 'string' then
    req.body = json.encode(req.body)
  end
  req.headers['Content-Type'] = 'application/json'
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
  client.backend = client.backend or backend

  return setmetatable(client, { __index  = generate_client_method  })
end

return http
