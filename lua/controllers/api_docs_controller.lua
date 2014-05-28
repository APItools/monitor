local http      = require 'http'
local h         = require 'controller_helpers'
local inspect   = require 'inspect'
local m         = require 'model_helpers'
local Service   = require 'models.service'
local ngxex     = require 'ngxex'

local get_code_from_host = function(code)
   return string.match(code, "^https?://(.*)-[^./]+")
end

local api_docs = { skip_csrf = true }

api_docs.proxy = function(params)
   local headers = ngx.req.get_headers()

   local custom_headers = {}
   local standard_headers = {}
   for k,v in pairs(headers) do
      local match = k:match('x-apidocs-.*', 1)
      if match then
         custom_headers[k] = v
      else
         standard_headers[k] = v
      end
   end

   local service, url = Service:find_by_endpoint_code(get_code_from_host(custom_headers['x-apidocs-url']))
   local path = tostring(custom_headers['x-apidocs-path'])

   standard_headers.host = string.match(url, "^.+://([^/]+)")

   -- normalize trailing and leading slashes
   if url:sub(#url) == '/' then
     url = url:sub(0, #url-1)
   end

   if path:sub(0,1) ~= '/' then
     path = '/' .. path
   end

   url = url .. path

   if custom_headers['x-apidocs-query'] then
      url = url .. '?' .. custom_headers['x-apidocs-query']
   end

   local body, status, headers = http.simple({
     method = custom_headers['x-apidocs-method'],
     url = url,
     headers = standard_headers
   }, ngxex.req_get_all_body_data())

   for name, value in pairs(headers) do
     ngx.header[name] = value
   end

   ngx.print( body )
   ngx.exit( status or ngx.HTTP_OK )
end

return api_docs
