local backend = {}
local response = require 'http_ng.response'
local http = require 'resty.http'

backend.send = function(request)
  local httpc = http.new()

  local res, err = httpc:request_uri(request.url, {
    method = request.method,
    body = request.body,
    headers = request.headers
  })

  if res then
    return response.new(res.status, res.headers, res.body)
  else
    return response.error(err)
  end
end


return backend
