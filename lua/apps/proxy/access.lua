local proxy_authorization = ngx.var.http_proxy_authorization
local proxy_connection  = ngx.var.http_proxy_connection

if proxy_connection and not proxy_authorization then
  ngx.header['Proxy-Authenticate'] = 'BASIC realm="brainslug"'
  ngx.header['Connection'] = 'close'
  ngx.exit(407) -- Proxy Authentication Required
end
