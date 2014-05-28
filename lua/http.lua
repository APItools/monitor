local proxy_location = "/___http_call"
local fun = require('functional')

local map = fun.map
local each = fun.each

-- keep compat with socket.url, just in case
local url = {
  escape =  function(s)
    return (string.gsub(s, "([^A-Za-z0-9_])",
                        function(c)
                          return string.format("%%%02x", string.byte(c))
                        end))
  end
}

local inspect = require 'inspect'

local methods = {
  ["GET"] = ngx.HTTP_GET,
  ["HEAD"] = ngx.HTTP_HEAD,
  ["PATCH"] = ngx.HTTP_PATCH,
  ["PUT"] = ngx.HTTP_PUT,
  ["POST"] = ngx.HTTP_POST,
  ["DELETE"] = ngx.HTTP_DELETE,
  ["OPTIONS"] = ngx.HTTP_OPTIONS
}
local set_proxy_location = function(loc)
  proxy_location = loc
end
local encode_query_string = function(t, sep)
  if sep == nil then
    sep = "&"
  end
  local i = 0
  local buf = { }
  for k, v in pairs(t) do
    if type(k) == "number" and type(v) == "table" then
      k, v = v[1], v[2]
    end
    buf[i + 1] = url.escape(k)
    buf[i + 2] = "="
    buf[i + 3] = url.escape(v)
    buf[i + 4] = sep
    i = i + 4
  end
  buf[i] = nil
  return table.concat(buf)
end

local simple = function(req, body)
  if type(req) == "string" then
    req = {
      url = req
    }
  end

  req.headers = req.headers or {}

  local host = req.headers.Host or req.headers.host
  local uagent = req.headers['User-Agent'] or 'APITools'

  if body then
    req.method = "POST"
    req.body = body
    req.headers["content-length"] = #body
  end
  if type(req.body) == "table" then
    req.body = encode_query_string(req.body)
    req.headers["Content-type"] = "application/x-www-form-urlencoded"
    req.headers["content-length"] = #req.body
  end

  req.headers.host = host or string.match(req.url, "^.+://([^/]+)")
  req.headers.Host = nil
  req.headers['User-Agent'] = uagent

  local res = ngx.location.capture(proxy_location, {
    method = methods[req.method or "GET"],

    body = req.body,
    ctx = {
      -- passing the original headers to new request makes nginx segfault
      headers = req.headers
    },
    vars = {
      _url = req.url
    }
  })

  return res.body, res.status, res.header
end

local function multi(reqs)

  local function prep_req(r)
    each(assert, {r.url, r.method})
    r.headers = r.headers or {}

    local host = r.headers.Host or r.headers.host
    local uagent = r.headers['User-Agent'] or 'Apitools'

    r.method = methods[r.method]
    r.body = r.body or ''

    if type(r.body) == 'table' then
      r.body = encode_query_string(r.body)
      r.headers["Content-type"] = "application/x-www-form-urlencoded"
      r.headers["content-length"] = #r.body
    end
    r.ctx = {
      headers = r.headers
    }
    r.vars = { _url = r.url }

    return {proxy_location, r}
  end

  local prepared_reqs = map(prep_req, reqs)

  return ngx.location.capture_multi(prepared_reqs)
end

local request
request = function(url, str_body)
  local return_res_body
  local req
  if type(url) == "table" then
    req = url
  else
    return_res_body = true
    req = {
      url = url,
      source = str_body and ltn12.source.string(str_body),
      headers = str_body and {
        ["Content-type"] = "application/x-www-form-urlencoded"
      }
    }
  end
  req.method = req.method or (req.source and "POST" or "GET")
  local body
  if req.source then
    local buff = { }
    local sink = ltn12.sink.table(buff)
    ltn12.pump.all(req.source, sink)
    body = table.concat(buff)
  end
  local res = ngx.location.capture(proxy_location, {
    method = methods[req.method],
    body = body,
    ctx = {
      headers = req.headers
    },
    vars = {
      _url = req.url
    }
  })
  local out
  if return_res_body then
    out = res.body
  else
    if req.sink then
      ltn12.pump.all(ltn12.source.string(res.body), req.sink)
    end
    out = 1
  end
  return out, res.status, res.header
end
local ngx_replace_headers
ngx_replace_headers = function(new_headers)
  if new_headers == nil then
    new_headers = nil
  end
  local req
  do
    local _obj_0 = ngx
    req = _obj_0.req
  end
  new_headers = new_headers or ngx.ctx.headers
  for k, v in pairs(req.get_headers()) do
    if k ~= 'content-length' and k ~= 'host' then
      req.clear_header(k)
    end
  end
  if new_headers then
    for k, v in pairs(new_headers) do
      req.set_header(k, v)
    end
  end
end

return {
  request = request,
  simple = simple,
  multi = multi,
  set_proxy_location = set_proxy_location,
  ngx_replace_headers = ngx_replace_headers
}
