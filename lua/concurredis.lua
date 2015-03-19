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
local resolver      = require 'resty.dns.resolver'
local lock          = require 'lock'

local concurredis = {}

local REDIS_NAMESERVER   = os.getenv('SLUG_REDIS_NAMESERVER')
local REDIS_DNS          = os.getenv('SLUG_REDIS_DNS')

local REDIS_HOST = os.getenv('REDIS_PORT_6379_TCP_ADDR') or os.getenv("SLUG_REDIS_HOST")
local REDIS_PORT = tonumber(os.getenv("SLUG_REDIS_PORT") or 6379)

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

local get_host_and_port = function()
  local host, port = REDIS_HOST, tonumber(REDIS_PORT)

  if host and port then
    ngx.log(ngx.INFO, ("Using redis server: %s:%d"):format(host, port))
    return host, port
  end

  local dict = ngx.shared.config_dict

  host = dict:get('redis-host')
  port = tonumber(dict:get('redis-port'))

  if host and port then
    ngx.log(ngx.INFO, ("Using cached redis server: %s:%d"):format(host, port))
    return host, port
  end

  assert(REDIS_NAMESERVER and REDIS_DNS, "Must set either [SLUG_REDIS_HOST, SLUG_REDIS_PORT] or [SLUG_REDIS_NAMESERVER, SLUG_REDIS_DNS]")

  ngx.log(ngx.INFO, ("Resolving DNS %s in %s"):format(REDIS_DNS, REDIS_NAMESERVER))

  local r = assert(resolver:new({
    nameservers = { REDIS_NAMESERVER },
    retrans     = 5,    -- 5 retransmissions on receive timeout
    timeout     = 2000  -- 2 sec
  }))

  lock.around('concurredis.resolve', function()
    local answers = assert(r:query(REDIS_DNS, r.TYPE_SRV))

    if answers.errcode then
      error(("Nameserver %s resolving DNS %s returned error code %s"):format(REDIS_NAMESERVER, REDIS_DNS, answers.errorcode))
    end

    if not answers[1] then
      error(("Nameserver %s resolving DNS %s returned no SRV answers"):format(REDIS_NAMESERVER, REDIS_DNS))
    end

    host = answers[1].target
    port = answers[1].port
  end)

  ngx.log(ngx.INFO, ("Using resolved redis server: %s:%s"):format(host, port))

  dict:set('redis-host', host)
  dict:set('redis-port', port)

  return host, tonumber(port)
end

local is_loaded = function(red)
  local info = red:info('persistence')
  local loading = info:match('loading:(%d)')
  return loading == '0'
end

---

concurredis.restart = function()
  concurredis.connect():shutdown()

  local host, port = get_host_and_port()
  local red        = redis:new()
  local sleep      = 0.1
  local growth     = 1.2

  while not red:connect(host, port) do
    ngx.sleep(sleep)
    sleep = sleep * growth
  end

  while not is_loaded(red) do
    ngx.sleep(sleep)
    sleep = sleep * growth
  end

  red:close()
end

concurredis.connect = function()
  local host, port = get_host_and_port()

  local red = redis:new()
  assert(red:connect(host, port))
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

    red:config('set', 'appendonly', 'no')
    red:config('set', 'appendonly', 'yes')
    red:config('set', 'appendfsync', 'always')
    red:set('last-save', ngx.now())
    red:bgrewriteaof()

    local appendonly = false
    while not appendonly do
      local progress = red:info('persistence'):match('aof_rewrite_in_progress:(%d)')

      if progress == '0' then
        appendonly = true
      end

      ngx.sleep(backoff)
    end

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
  concurredis.execute(function(red)
    local _, message = red:shutdown()
    assert(message == 'closed', message)
  end)
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
