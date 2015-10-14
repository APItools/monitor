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

local redis          = require 'resty.redis'
local error_handler  = require 'error_handler'
local resolver       = require 'resty.dns.resolver'
local lock           = require 'lock'

local concurredis = {}

local REDIS_NAME_SERVER  = os.getenv('SLUG_REDIS_NAME_SERVER')
local REDIS_NAME         = os.getenv('SLUG_REDIS_NAME')
local REDIS_HOST         = os.getenv('DB_PORT_6379_TCP_ADDR') or  os.getenv('REDIS_PORT_6379_TCP_ADDR') or os.getenv("SLUG_REDIS_HOST")
local REDIS_PORT         = tonumber( os.getenv('DB_PORT_6379_TCP_PORT') or os.getenv('REDIS_PORT_6379_TCP_PORT') or os.getenv("SLUG_REDIS_PORT") or 6379)

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

local is_loaded = function(red)
  local info = red:info('persistence')
  local loading = info:match('loading:(%d)')
  return loading == '0'
end

local save_host_and_port_in_cache = function(host, port)
  local dict = ngx.shared.config_dict
  dict:set('redis-host', host)
  dict:set('redis-port', port)
end

local make_dns_query = function(r, name, query_type)
  ngx.log(ngx.INFO, ("Performing DNS query of type %s for %s"):format(query_type, name))
  local answers = assert(r:query(name, {qtype = query_type}))

  if answers.errcode then
    error(("Name server %s resolving name %s with query type %s returned error code %s"):format(REDIS_NAME_SERVER, name, query_type, answers.errorcode))
  end

  if not answers[1] then
    error(("Name server %s resolving name %s with query type %s returned no answers"):format(REDIS_NAME_SERVER, name, query_type))
  end

  return answers
end

local get_connection_from_cache = function()
  local dict = ngx.shared.config_dict
  local red, host, port

  host, port = dict:get('redis-host'), tonumber(dict:get('redis-port'))

  if host and port then
    red = redis:new()
    if red:connect(host, port) then
      ngx.log(ngx.INFO, ("Connected with redis using CACHED values - %s:%d"):format(host, port))
    else
      red, host, port = nil, nil, nil
      ngx.log(ngx.INFO, "Redis cached connection expired: %s with %d"):format(host, port)
      dict:delete('redis-host')
      dict:delete('redis-port')
    end
  end

  return red, host, port
end

local get_connection_from_dns = function()
  if not REDIS_NAME_SERVER or not REDIS_NAME then return end

  ngx.log(ngx.INFO, ("Resolving name %s with server %s"):format(REDIS_NAME, REDIS_NAME_SERVER))

  local red, host, port

  local r = assert(resolver:new({
    nameservers = { REDIS_NAME_SERVER },
    retrans     = 5,    -- 5 retransmissions on receive timeout
    timeout     = 2000  -- 2 sec
  }))

  lock.around('concurredis.resolve', function()
    local answer_srv = make_dns_query(r, REDIS_NAME, r.TYPE_SRV)[1]
    port = answer_srv.port

    ngx.log(ngx.INFO, ("Got target %s and port %s from DNS SRV request"):format(answer_srv.target, port))

    local answer_a = make_dns_query(r, answer_srv.target, r.TYPE_A)
    for i=1,#answer_a do
      if answer_a[i].address then
        host = answer_a[i].address
        ngx.log(ngx.INFO, ("Got host %s from DNS A request"):format(host))
        break
      end
    end
  end)

  if not host or not port then
    error(('Could not obtain redis host and port from DNS: %s, %s. Obtained host: %s, port: %s'):format(REDIS_NAME_SERVER, REDIS_NAME, host, port))
  end

  local red = redis:new()
  assert(red:connect(host, port))
  save_host_and_port_in_cache(host, port)

  ngx.log(ngx.INFO, ("Connected with redis using DNS values - %s:%d"):format(host, port))

  return red, host, port
end

local get_connection_from_env = function()
  local host, port = REDIS_HOST, REDIS_PORT

  if not host or not port then return end

  local red = redis:new()
  assert(red:connect(host, port))
  save_host_and_port_in_cache(host, port)

  ngx.log(ngx.INFO, ("Connected with redis using ENV values - %s:%d"):format(host, port))
  return red
end

---

concurredis.restart = function()
  local red, host, port = concurredis.connect()

  red:shutdown()

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
  local red = get_connection_from_cache() or get_connection_from_dns() or get_connection_from_env()

  if not red then
    error('Could not connect to redis. Make sure that (SLUG_REDIS_HOST + SLUG_REDIS_PORT) or (SLUG_REDIS_NAME_SERVER + SLUG_REDIS_NAME_SERVER) are set')
  end

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
