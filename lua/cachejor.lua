local redis   = require('concurredis')
local json = require('cjson')
local inspect = require 'inspect'

local cachejor = {}
local cache = { version = 1, ttl = 60 }
local redisstore = {}

local store = redisstore

-- redis backend store
function redisstore:encode(...)
  local obj = {value = ... }
  local ok, str = pcall(json.encode, obj)

  if ok then
    return str
  else
    return nil, str
  end
end

function redisstore:decode(str)
  local ok, obj = pcall(json.decode, str)

  if ok then
    return obj.value
  else
    return nil, obj
  end
end

function redisstore:save(value, ...)
  if type(value) == "function" then
    return
  end
  local key, field = cache:key(...)
  local value, err = redisstore:encode(value)

  redis.execute(function(red)
    red:hset(key, field, value)
    red:expire(key, cache.ttl)
  end)
end

function redisstore:remove(key, field)
  redis.execute(function(red) red:hdel(key, field) end)
end

function redisstore:load(...)
  local key, field = cache:key(...)
  local value

  redis.execute(function(red) value = red:hget(key,field) end)

  if value and value ~= ngx.null then
    local ok, err = redisstore:decode(value)

    if not ok and err then
      ngx.log(ngx.ERR, '[cachejor] failed to decode key: ' .. key .. '.' .. field .. ' with value: ' .. value)
      redisstore:remove(key, field)
    end

    return ok
  end
end

function redisstore:wipe(collection)
  local key, _ = cache:key(collection)

  redis.execute(function(red)
     red:del(key)
  end)
end

function redisstore:reset()
  -- TODO: wipe redis cache keys
end

-- cache object to store/retrieve the data
function cache:store(driver, ...)
  local res, err = driver:find(...)

  if res then
    pcall(store.save, store, res, ...)
  end

  return res, err
end

function cache:lookup(...)
  local val = store:load(...)
  return val
end

function cache:clear(collection)
  store:wipe(collection)
  return true
end

function cache:key(collection, ...)
  local key = ""

  for i,part in ipairs({...}) do
    part = json.encode(part)
    key = key .. "/" .. part
  end

  return "jor/cache/" .. cache.version .. "/" .. collection, key
end

-- JOR driver api
function cachejor:find(...)
  return cache:lookup(...) or cache:store(self.driver, ...)
end

function cachejor:update(...)
  return cache:clear(...) and self.driver:update(...)
end

function cachejor:delete(...)
  return cache:clear(...) and self.driver:delete(...)
end

function cachejor:insert(...)
  return cache:clear(...) and self.driver:insert(...)
end

function cachejor:new(driver)
  local cache = { driver = driver }
  setmetatable(cache, { __index = function(table, key) return cachejor[key] or driver[key] end })
  return cache
end

return cachejor
