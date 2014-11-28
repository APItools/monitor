local statsd = require 'statsd'
local statsd_wrapper = {}

local statsd_server = os.getenv('STATSD_PORT_8125_UDP_ADDR') or os.getenv('SLUG_STATSD_SERVER')

if statsd_server then
  ngx.log(ngx.INFO, 'using statsd server on ' .. statsd_server)
end

local statsd_null = {
  time = function() end,
  timer = function() end,
  count = function() end,
  gauge = function() end,
  flush = function() end
}

local function get_instance()
  if not ngx.ctx.statsd_instance then
    local instance
    if statsd_server then
      local statsd_port = os.getenv('SLUG_STATSD_PORT') or 8125
      local Config      = require 'models.config'
      local instance_id = Config and Config.get_slug_name(true) or 'no_host'
      local env         = os.getenv('SLUG_ENV') or 'dev'
      local namespace   = 'brainslug.' .. env .. '.' .. instance_id

      ngx.ctx.statsd_instance = statsd.new(statsd_server, statsd_port, namespace)
    else
      ngx.ctx.statsd_instance = statsd_null
    end
  end
  return ngx.ctx.statsd_instance
end

function statsd_wrapper.time(bucket, value)
  local instance = get_instance()
  instance:time(bucket, value)
  instance:flush(false)
end

function statsd_wrapper.timer(bucket, fun, ...)
  local start = ngx.now()
  local ret = {fun(...)}
  local time = ngx.now() - start
  ngx.log(ngx.INFO, bucket .. ' took ' .. time)
  statsd_wrapper.time(bucket, time)
  return unpack(ret)
end

function statsd_wrapper.count(bucket, n)
  local instance = get_instance()
  instance:count(bucket, nv)
  instance:flush(false)
end

function statsd_wrapper.gauge(bucket, value)
  local instance = get_instance()
  instance:gauge(bucket, value)
  instance:flush(false)
end

function statsd_wrapper.flush(force)
  get_instance():flush(force)
end

return statsd_wrapper
