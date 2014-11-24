-- note that the red variable can not be included as a module level to avoid concurrency problems
-- This library must be used like this:
--
-- local redis = require('concurredis')
--
-- redis.execute(function(red)
--   <do stuff with red>
-- end)
--
-- See https://github.com/agentzh/lua-resty-redis#limitations for details

local redis         = require 'resty.redis'
local error_handler = require 'error_handler'

local concurredis = {}

local POOL_SIZE = 30
local KEEPALIVE_TIMEOUT = 30 * 1000 -- 30 seconds in ms

local expand_gmatch = function(text, match)
  local result = {}

  local f     = ngx.re.gmatch(text, match)
  local match = f and f()

  while match do
    result[match[1]] = match[2]
    match = f()
  end

  return result
end

concurredis.host = os.getenv("SLUG_REDIS_HOST")
concurredis.port = os.getenv("SLUG_REDIS_PORT")
concurredis.port = concurredis.port or 6379

ngx.log(ngx.INFO, "Using redis server: " .. tostring(concurredis.host) .. ":" .. tostring(concurredis.port))

concurredis.connect = function()
  local red = redis:new()
  assert(red:connect(concurredis.host, concurredis.port))
  return red
end

concurredis.execute = function(f)

  local first_connection = false
  if not ngx.ctx.red then
    ngx.ctx.red = concurredis.connect()
    first_connection = true
  end

  local red = ngx.ctx.red

  local result  = { error_handler.execute(function() return f(red) end) }

  if first_connection then
    red:set_keepalive(KEEPALIVE_TIMEOUT, POOL_SIZE)
    ngx.ctx.red = nil
  end

  local ok, err = result[1], result[2]
  if ok then
    table.remove(result, 1) -- remove ok from first position
    return unpack(result)
  else
    error(err)
  end
end

concurredis.disable_bgsave = function(fun)
  return concurredis.execute(function(red)
    local save = red:config('get', 'save')

    local res, err = pcall(fun, red)

    assert(red:config('set', unpack(save)))
    assert(res, err)
  end)

end

concurredis.save = function()
  concurredis.disable_bgsave(function(red)
    local backoff = 0.01
    local total = 0

    while not red:save() do
      total = total + backoff
      ngx.sleep(backoff)

      if total > 15 then
        assert(red:save())
      end
    end
  end)
end

concurredis.config = function(key, value)
    concurredis.execute(function(red) assert(red:config('set', key, value)) end)
end

concurredis.shutdown = function()
  concurredis.execute(function(red) assert(red:shutdown()) end)
end

concurredis.stats = function(section)
  local info = concurredis.execute(function(red) return red:info(section) end)
  return expand_gmatch(info, '(\\w+?):(.+)\r')
end

concurredis.status = function()
  local ping = pcall(concurredis.execute, function(red) return red:ping() end)
  local info = ping and concurredis.stats()
  return { ping = ping, info = info }
end

concurredis.keys = function()
  return concurredis.execute(function(red)
    local keys = red:keys("*")
    local stats = {}

    for i,key in ipairs(keys) do
      local debug = red:debug('object', key)
      stats[key] = expand_gmatch(debug, '(\\w+?):([^ ]+)')
      stats[key].at = nil
    end

    return stats
  end)
end

return concurredis
