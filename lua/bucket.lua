------------
--- Bucket
-- In memory Key/Value store.
-- @module middleware

local luajson = require 'json'

--- Bucket
-- @type Bucket

local Bucket = {}

local Bucket_methods = {}

local function get_id(self)
  return getmetatable(self).id
end

local function get_key(self, field_name)
  return get_id(self) .. "/" .. field_name
end

--- get a value
-- @return value previously stored
-- @param field_name name
-- @function bucket.get

function Bucket_methods:get(field_name)
  local key = get_key(self, field_name)
  local encoded = ngx.shared.buckets:get(key)
  if not encoded then return nil end
  return luajson.decode(encoded)
end


--- set a value
-- @tparam string field_name key name
-- @param value value
-- @tparam int exptime time to expire in seconds
-- @return value previously stored
-- @function bucket.get

function Bucket_methods:set(field_name, value, exptime)
  exptime = exptime or 0
  local key     = get_key(self, field_name)
  local encoded = luajson.encode(value)
  return ngx.shared.buckets:set(key, encoded, exptime)
end

--- delete a value
-- @tparam string field_name a key
-- @return value previously stored
-- @function bucket.delete

function Bucket_methods:delete(field_name)
  local key = get_key(self, field_name)
  return ngx.shared.buckets:delete(key)
end


--- increment a value
-- @tparam string field_name a key
-- @tparam number amount amount to increment/decrement (default 1)
-- @return value previously stored
-- @function bucket.incr

function Bucket_methods:incr(field_name, amount)
  amount = amount or 1
  local key = get_key(self, field_name)
  ngx.shared.buckets:add(key, 0)
  return ngx.shared.buckets:incr(key, amount)
end


--- set the value if it does not exist
-- @param[type=string] field_name a key
-- @param value value
-- @tparam int exptime expire time in seconds
-- @function bucket.add

function Bucket_methods:add(field_name, value, exptime)
  exptime = exptime or 0
  local key     = get_key(self, field_name)
  local encoded = luajson.encode(value)
  return ngx.shared.buckets:add(key, encoded, exptime)
end

--- delete all values
-- @function bucket.delete_all

function Bucket_methods:delete_all()
  for _,field_name in ipairs(self:get_keys()) do -- warning self:get_keys is inefficient
    self:delete(field_name)
  end
end

--- get all keys
-- @treturn {string, ...} all keys
-- @function bucket.get_keys

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
