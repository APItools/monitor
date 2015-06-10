local m               = require 'model_helpers'
local inspect         = require 'inspect'

local System          = {}
local Config          = require 'models.config'
local MiddlewareSpec  = require 'models.middleware_spec'
local shared_dict     = require 'shared_dict'
local jor             = require 'jor'
local crontab         = require 'crontab'
local statsd          = require 'statsd_wrapper'

local redis           = require 'concurredis'

System.is_initialized = function()
  return Config.get().initialized
end

System.initialize = function()
  MiddlewareSpec:ensure_defaults_exist()
  Config.update_missing({ initialized = true })
  -- This ensures that crontab is re-launched if it dies
  crontab.initialize()
end

System.reset = function()
  statsd:flush(true)
  shared_dict.reset() -- this should go before crontab.reset
  jor:reset()
  Config.reset()
  crontab.reset()
end

System.cron_flush = function()
  crontab.flush()
end

System.cron_stats = function()
  return crontab.stats()
end

System.status = function()
  local cron = System.cron_stats()
  local redis = redis.status()
  local pid = ngx.worker.pid()

  return { cron = cron, redis = redis, pid = pid }
end

System.logfile = os.getenv('SLUG_LOGFILE')

System.log = function(block)
  local log = io.open(System.logfile)
  log:seek('end')

  local loop = function(file, block, wait_time)
    local abort = false
    ngx.on_abort(function() abort = true end)

    repeat
      for line in file:lines() do
        block(line)
      end
      ngx.sleep(wait_time)
    until abort
  end

  local co = ngx.thread.spawn(loop, log, block, 0.5)
  local ok, res = ngx.thread.wait(co)
  log:close()
  return ok, res
end

System.run_timer = function(timer_id)
  local timer = crontab.get_timer(timer_id)

  if timer then
    crontab.run(timer, 'manual')
  end
end

return System
