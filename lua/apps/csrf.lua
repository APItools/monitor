local csrf           = require 'csrf'
local resty_cookie   = require 'resty.cookie'

local cookie = resty_cookie:new()
local csrf_token = csrf.generate_token()

local is_secure = ngx.var.http_forwarded_proto == 'https'

local ok, err = cookie:set({
  key = "XSRF-TOKEN", value = csrf_token, path = "/",
  secure = is_secure, httponly = false, max_age = csrf.expires
})

if not ok then
  ngx.log(ngx.ERR, 'failed to set cookie: ' .. tostring(err))
end
