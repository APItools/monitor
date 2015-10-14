local CONTAINS_DASH = "^(.*)%-([^.]+)"

if string.match(ngx.var.http_host, CONTAINS_DASH) then
  ngx.var.port = 10002
else
  ngx.var.port = 7071
end
