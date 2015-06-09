local _M = {}
local response = require 'http_ng.response'
local http = require 'resty.http'

local function async_response(client, req)
  local response_read = false
  local function load(table)
    if response_read == false then
      local res, err = client:read_response(req)
      response_read = true

      if not res then
        error(err)
      else
        table.status = res.status
        table.headers = response.headers.new(res.headers)
        table.body = res.read_body(res)
      end

      client:set_keepalive()
    end
  end

  return setmetatable({}, {
    __gc = function() -- this does not work, but could in the future
      if not response_read then client:close() end
    end,
    __len = function(res)
      load(res)
      return 0
    end,
    __index = function(res, key)
      load(res)
      return rawget(res, key)
    end
  })
end

_M.async = function(req)
  local httpc = http.new()

  local parsed_uri = assert(httpc:parse_uri(req.url))

  local scheme, host, port, path = unpack(parsed_uri)
  if not req.path then req.path = path end

  if #req.path == 0 then req.path = '/' end

  assert(httpc:connect(host, port))

  if scheme == 'https' then
    local verify = req.options and req.options.ssl.verify or true
    assert(httpc:ssl_handshake(false, host, verify))
  end

  local res, err = httpc:request(req)

  if res then
    return response.new(res.status, res.headers, function() return (res:read_body()) end)
  else
    return response.error(err)
  end
end

local function future(thread)
  local ok, res

  local function load(table)
    if not ok and not res then
      ok, res = ngx.thread.wait(thread)

      rawset(table, 'ok', ok)
      if not ok then res = response.error(res) end

      for k,v in pairs(res) do
        rawset(table, k, v)
      end
    end
  end

  return setmetatable({}, {
    __len = function(table)
      load(table)
      return rawlen(table)
    end,
    __pairs = function(table)
      load(table)
      rawset(table, 'body', res.body)
      return next, table, nil
    end,
    __index = function (table, key)
      load(table)
      return res[key]
    end
  })
end

_M.send = function(request)
  local thread = ngx.thread.spawn(_M.async, request)
  return future(thread)
end

return _M
