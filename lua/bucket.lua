local luajson = require 'json'

local Bucket = {}

----------------------------------------
local Bucket_methods = {}

local function get_id(self)
  return getmetatable(self).id
end

local function get_key(self, field_name)
  return get_id(self) .. "/" .. field_name
end

function Bucket_methods:get(field_name)
  local key = get_key(self, field_name)
  local encoded = ngx.shared.buckets:get(key)
  if not encoded then return nil end
  return luajson.decode(encoded)
end

function Bucket_methods:set(field_name, value, exptime)
  exptime = exptime or 0
  local key     = get_key(self, field_name)
  local encoded = luajson.encode(value)
  return ngx.shared.buckets:set(key, encoded, exptime)
end

function Bucket_methods:delete(field_name)
  local key = get_key(self, field_name)
  return ngx.shared.buckets:delete(key)
end

function Bucket_methods:incr(field_name, amount)
  amount = amount or 1
  local key = get_key(self, field_name)
  ngx.shared.buckets:add(key, 0)
  return ngx.shared.buckets:incr(key, amount)
end

function Bucket_methods:add(field_name, value, exptime)
  exptime = exptime or 0
  local key     = get_key(self, field_name)
  local encoded = luajson.encode(value)
  return ngx.shared.buckets:add(key, encoded, exptime)
end

function Bucket_methods:delete_all()
  for _,field_name in ipairs(self:get_keys()) do -- warning self:get_keys is inefficient
    self:delete(field_name)
  end
end

function Bucket_methods:get_keys()
  local result, len = {}, 0
  local id = get_id(self)
  for _,key in ipairs(ngx.shared.buckets:get_keys(0)) do -- FIXME: get_keys is inefficient
    if key:sub(1, #id) == id then
      len = len + 1
      result[len] = key:sub(#id + 2) -- + 2 because there is a '/' after the id
    end
  end
  return result
end

----------------------------------------

local function makeDotMethod(bucket, name)
  local method = Bucket_methods[name]
  if method then
    local f = function(...) return method(bucket, ...) end
    rawset(bucket, name, f)
    return f
  end
end

function Bucket.for_middleware(service_id, middleware_uuid)
  return setmetatable({}, {
    id      = 'mw/' .. tostring(service_id) .. '.' .. tostring(uuid),
    __index = makeDotMethod
  })
end

function Bucket.for_service(service_id)
  return setmetatable({}, {
    id      = 's/' .. tostring(service_id),
    __index = makeDotMethod
  })
end

return Bucket
