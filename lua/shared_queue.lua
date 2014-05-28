local inspect = require 'inspect'
local Queue = {}
local cjson = require 'cjson'
local resty_lock = require "resty.lock"

local function encode(obj)
  return cjson.encode(obj)
end

local function decode(str)
  return cjson.decode(str)
end

function Queue:new(name)
  local obj = { name = name, dict = ngx.shared.queues }
  self.__index = self
  return setmetatable(obj, self)
end

function Queue:incr(key, increment)
  assert(key) -- need key to increment

  local key = self:prefix(key)
  local increment = increment or 1
  local id, err = self.dict:incr(key, increment)

  if err then
    local ok, err = self.dict:add(key, increment)
    if ok then
      return increment
    else
      error("shared queue error getting next id: " .. err)
    end
  end

  return id
end

function Queue:decr(key)
  return self:incr(key, -1)
end

function Queue:prefix(key)
  return self.name .. "-" .. key
end

function Queue:push(obj)
  local id = assert(self:incr('head'))
  local key = self.name .. "-" .. tostring(id)

  local ok, err = self.dict:add(key, encode(obj))
  if not ok and error then
    error("error pushing to queue " .. self.name .. ": " .. err)
  end
  local count = self:incr('count')
end

function Queue:free()
  self.dict:flush_expired()
end

function Queue:pop()
  local lock = resty_lock:new('locks')
  local elapsed = lock:lock("queue-" .. self.name)

  if elapsed then
    ngx.log(ngx.INFO, '[sq] took ' .. elapsed .. ' to unlock ' .. self.name .. ' queue')
  end

  local stored = self:get('head')
  local processed = self:get('tail')

  if processed < stored then -- FIXME: not thread safe, needs locks or different structure
    local next_id = self:incr('tail')
    local key = self:prefix(next_id)

    local value = self.dict:get(key)

    if value then
      self.dict:delete(key)
      self:decr('count')
      lock:unlock()
      return decode(value)
    end
  end

  lock:unlock()

  return
end

function Queue:size()
  return self:get('count')
end

function Queue:get(key)
  local key = self:prefix(key)
  return self.dict:get(key) or 0
end

return Queue


