local backend = {}
local response = require 'http_ng.response'

local METHODS = {
  ["GET"]      = ngx.HTTP_GET,
  ["HEAD"]     = ngx.HTTP_HEAD,
  ["PATCH"]    = ngx.HTTP_PATCH,
  ["PUT"]      = ngx.HTTP_PUT,
  ["POST"]     = ngx.HTTP_POST,
  ["DELETE"]   = ngx.HTTP_DELETE,
  ["OPTIONS"]  = ngx.HTTP_OPTIONS
}

local PROXY_LOCATION = '/___http_call'

backend.capture = ngx.location.capture
backend.send = function(request)
  local res = backend.capture(PROXY_LOCATION, {
    method = METHODS[request.method],
    body = request.body,
    ctx = {
      headers = request.headers
    },
    vars = {
      _url = request.url
    }
  })

  if res.truncated then
    -- Do what? what error message it should say?
  end

  return response.new(res.status, res.header, res.body)
end

return backend
