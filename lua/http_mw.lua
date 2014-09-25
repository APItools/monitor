local fun = require('functional')

local http = {}

local map = fun.map
local each = fun.each

local PROXY_LOCATION = "/___http_call"
local METHODS = {
  ["GET"]      = ngx.HTTP_GET,
  ["HEAD"]     = ngx.HTTP_HEAD,
  ["PATCH"]    = ngx.HTTP_PATCH,
  ["PUT"]      = ngx.HTTP_PUT,
  ["POST"]     = ngx.HTTP_POST,
  ["DELETE"]   = ngx.HTTP_DELETE,
  ["OPTIONS"]  = ngx.HTTP_OPTIONS
}

local char_escape = function(c)
  return string.format("%%%02x", string.byte(c))
end

local url_escape = function(s)
  return string.gsub(s, "([^A-Za-z0-9_])", char_escape)
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
    buf[i + 1] = url_escape(k)
    buf[i + 2] = "="
    buf[i + 3] = url_escape(v)
    buf[i + 4] = sep
    i = i + 4
  end
  buf[i] = nil
  return table.concat(buf)
end

local init_headers = function(req)
  local headers = req.headers or {}

  local uagent = headers['User-Agent'] or 'APITools'
  local host = headers.Host or headers.host

  headers.host = host or string.match(req.url, "^.+://([^/]+)")
  headers.Host = nil

  headers['User-Agent'] = uagent

  return headers
end

local init_req = function(r)
  each(assert, {r.url, r.method})

  r.headers = init_headers(r)
  r.method = METHODS[r.method]
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

  return {PROXY_LOCATION, r}
end

-------------------------

function http.set_proxy_location(loc)
  PROXY_LOCATION = loc
end

function http.simple(req, body)
  if type(req) == "string" then
    req = { url = req }
  end

  req.headers = init_headers(req)

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

  local res = ngx.location.capture(PROXY_LOCATION, {
    method = METHODS[req.method or "GET"],

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

function http.multi(reqs)
  local initialized_reqs = map(init_req, reqs)
  return { ngx.location.capture_multi(initialized_reqs) }
end

function http.request(url, str_body)
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
  local res = ngx.location.capture(PROXY_LOCATION, {
    method = METHODS[req.method],
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

function http.ngx_replace_headers(new_headers)
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

function http.is_success(status)
  return status >= 200 and status < 300
end

function encode_qp(t, prefix)
  prefix = prefix or ''
  local res = {}

  if type(t) == 'table' then
    for k, v in pairs(t) do
      local npref
      if prefix == '' then  npref = k else npref = prefix .. '['..k..']' end
      res[#res+1] = encode_qp(v, npref)
    end
    return table.concat(res, '&')

  else
    local r = prefix ..'='.. t
    return r
  end
end

function http.get(url, params, headers)
  params = params or ''

  if type(params) == 'table' then
    params = encode_qp(params)
  end

  local full_url = url
  if not (params == '') then
    full_url = string.format('%s?%s', full_url, params)
  end

  return http.simple{
    method = METHODS.GET,
    url = full_url,
    headers = headers or {}
  }
end

function http.post(url, params, headers)
  params = params or ''

  if type(params) == 'table' then
    params = encode_qp(params)
  end

  return http.simple{
    method = METHODS.POST,
    url = url,
    headers = headers or {},
    body = params
  }
end

function http.put(url, params, headers)


end

return http
