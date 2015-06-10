local error_handler  = require 'error_handler'
local uuid4          = require 'uuid'
local statsd         = require 'statsd_wrapper'
local resty_lock     = require 'resty.lock'

local minute = 60
local hour   = 60*minute
local day    = 24*hour
local week   = 7*day
local month  = 30*day


local crontab = {}

-- private functions

local TIMERS = {
  { id = 'process_pending_events',
    every = 5,
    action = function()
      local EventObserver = require 'models.event_observer'
      EventObserver:process_events(5)
    end
  },
  { id = 'delete_expired_traces',
    every = 10,
    action = function()
      local Trace = require 'models.trace'
      ngx.log(0, 'deleting expired traces...')

      Trace:delete_expired()
    end
  },
  { id = 'async_traces',
    every = 1,
    action = function()
      local Trace = require 'models.trace'
      local consumed = Trace:consume()
    end
  },
  { id = 'async_swagger',
    every = 1,
    action = function()
      local AutoswaggerHost = require 'models.autoswagger_host'
      local consumed = AutoswaggerHost:consume()
    end
  },
  { id = 'delete_expired_events',
    every = 10,
    action = function()
      local Event = require 'models.event'
       Event:delete_expired(1000)
    end
  },
  { id = 'flush_collector',
    every = 5,
    action = function()
      local collector = require 'collector'
      collector.flush()
    end
  },
  { id = 'flush_statsd',
    every = 1,
    action = function()
      statsd.flush()
    end
  },
  { id = 'compact_metrics_minute',
    every = minute,
    action = function()
      local Metric = require 'models.metric'
      -- This will break minute metrics if saving a jmetric takes more than 2 minutes. I can live with that (kikito)
      Metric:compact(nil, ngx.now() - minute, Metric:default_granularity())
    end
  },
  { id = 'compact_metrics_hour',
    every = hour,
    action = function()
      local Metric = require 'models.metric'
      Metric:compact(nil, ngx.now() - hour, minute)
    end
  },
  { id     = 'compact_metrics_day',
    every  = day,
    at     = 'midnight',
    offset = 1*hour,
    action = function()
      local Metric = require 'models.metric'
      Metric:compact(nil, ngx.now() - day, hour)
    end
  },
  { id     = 'compact_metrics_week',
    every  = day,
    at     = 'midnight',
    offset = 1*hour,
    action = function()
      local Metric = require 'models.metric'
      Metric:compact(nil, ngx.now() - week, day)
    end
  },
  { id     = 'report_to_brain',
    every  = 5*minute,
    offset = 5*minute,
    action = function()
      local Brain  = require 'brain'
      Brain.trigger_report()
    end
  },
  { id     = 'send_emails',
    every  = minute,
    offset = 10,
    action = function()
      local mail  = require 'consumers.mail'
      mail.run()
    end
  },
  { id     = 'send_redis_stats',
    every  = 10,
    action = function()
      local redis = require 'concurredis'
      local stats = redis.stats('persistence')

      for k,v in pairs(stats) do
        if  tonumber(v)          -- ignore non-numerical values
        and not k:match('^rdb_') -- also ignore rdb values (deactivated)
        then
          statsd.gauge('redis.' .. k, tonumber(v))
        end
      end
    end
  },
  { id = 'send_cron_stats',
    every = 5,
    action = function()
      local stats = crontab.stats()
      for k,v in pairs(stats) do
        if tonumber(v) then statsd.gauge('cron.' .. k, tonumber(v)) end
      end
      for k,v in pairs(stats.jobs) do
        statsd.gauge('cron.' .. k .. '_scheduled', v)
      end
    end
  }
}

local TIMERS_DICT = {}
for _,timer in ipairs(TIMERS) do TIMERS_DICT[timer.id] = timer end

local dict    = ngx.shared.crontab

local function get_job_keys()
  local all_keys = dict:get_keys()
  local job_keys, len = {}, 0

  for i=1,#all_keys do
    local key = all_keys[i]
    if not TIMERS_DICT[key] then
      len = len + 1
      job_keys[len] = key
    end
  end

  table.sort(job_keys)

  return job_keys, len
end

local get_jobs = function()

  local jobs = {}
  for i=1, #TIMERS do jobs[TIMERS[i].id] = 0 end

  local job_keys, len = get_job_keys()

  for i=1, len do
    local key = job_keys[i]
    local timer_id = dict:get(key)
    jobs[timer_id] = jobs[timer_id] + 1
  end

  return jobs
end

local get_seconds_to_midnight = function()
  local yyyy, mm, dd  = (ngx.today()):match("(%d%d%d%d)-(%d%d)-(%d%d)")
  local last_midnight = os.time({ year = tonumber(yyyy), month = tonumber(mm), day = tonumber(dd) })
  local next_midnight = last_midnight + 1 * day

  return next_midnight - ngx.now()
end

local get_seconds_to_next_execution = function(timer, offset)
  offset = offset or 0
  if timer.at == 'midnight' then
    return get_seconds_to_midnight() + offset
  else
    return timer.every + offset
  end
end


-- Public functions

crontab.schedule = function(timer, offset)
  if dict:get(timer.id) then
    local delay      = get_seconds_to_next_execution(timer, offset)
    local job_id     = crontab.uuid(timer)
    local scheduled  = dict:add(job_id, timer.id)

    if scheduled then
      local ok, err = ngx.timer.at(delay, crontab.run_and_reschedule, timer, job_id)
      if ok then
        ngx.log(ngx.INFO, '[cron] scheduled ' .. timer.id .. ' with as ' .. job_id .. ' in ' .. delay .. ' seconds')
      else
        ngx.log(ngx.ERR, '[cron] could not execute ngx.timer.at for ' .. timer.id .. ' error: ' .. err )
      end
    else
      ngx.log(ngx.ERR, '[cron] could not schedule ' .. timer.id .. ' with as ' .. job_id)
    end
  else
    ngx.log(ngx.ERR, "can't schedule timer " .. timer.id .. " because it is not initialized")
  end
end

crontab.uuid = function(timer)
  return timer.id .. '-' .. uuid4.getUUID()
end

crontab.run_and_reschedule = function(premature, timer, job_id)
  if not dict:get_stale(job_id) then
    ngx.log(ngx.INFO, 'job ' .. job_id .. ' of timer ' .. timer.id .. ' is not scheduled')
    return
  end

  crontab.run(timer, job_id)

  dict:set(timer.id, true, timer.every)

  if not premature then
    crontab.lock(crontab.schedule, timer)
  end
end

-- blocking lock - does not execute if resource is locked
crontab.block = function(fun, ...)
  local lock = resty_lock:new('locks', { timeout = 0, max_step = 0 })

  local elapsed, err = lock:lock('crontab')

  if err then
    ngx.log(ngx.INFO, '[cron] lock prevented from running passed function: ' .. err)
    return nil, err
  end

  local ret, err = pcall(fun, ...)

  lock:unlock()

  return ret, err
end

crontab.lock = function(fun, ...)
  if ngx.ctx.crontab_lock then -- short cirguit when locking inside already locked ctx
    ngx.log(ngx.INFO, 'lock already acquired, skipping locking')
    return pcall(fun, ...)
  end

  local lock = resty_lock:new('locks')
  local elapsed, err = lock:lock('crontab')

  if not elapsed and err then
    ngx.log(ngx.ERR, 'failed to acquire lock')
    return nil, err
  end

  ngx.log(ngx.INFO, 'acquired lock in ' .. tostring(elapsed) .. ' seconds')
  ngx.ctx.crontab_lock = true

  local start = ngx.now()
  local ret, err = pcall(fun, ...)
  local elapsed = ngx.now() - start

  lock:unlock()
  ngx.ctx.crontab_lock = nil
  ngx.log(ngx.INFO, 'released lock after ' .. tostring(elapsed) .. ' seconds')

  return ret, err
end

crontab.randomizer = function(timer)
  if timer.offset then
    return math.random(0, timer.offset) -- integer between 0 and timer.offset
  else
    return math.random() -- float between 0 and 1
  end
end

crontab.initialize = function()
  -- it wont run initialize when locked
  crontab.block(function()
    ngx.log(ngx.INFO, '[cron] initializing')
    dict:flush_expired()

    for _,timer in ipairs(TIMERS) do
      local ok, err = dict:add(timer.id, true, timer.every)

      if ok then
        crontab.schedule(timer, crontab.randomizer(timer))
      else
        ngx.log(ngx.DEBUG, '[crontab] timer ' .. timer.id .. ' already initialized. Error: ' .. err)
      end
    end

    ngx.log(ngx.INFO, '[cron] initialized')
  end)
end

crontab.flush = function()
  crontab.lock(function()
    for _,timer in ipairs(TIMERS) do
      crontab.run(timer, 'forced')
    end
  end)
end

crontab.get_timer = function(id)
  return TIMERS_DICT[id]
end

crontab.run = function(timer, job_id)
  ngx.log(ngx.INFO, '[cron] running ' .. timer.id .. ' job  ' .. job_id)

  crontab.lock(function()
    statsd.timer('cron.' .. timer.id, function()
      error_handler.execute(timer.action)
    end)
  end)

  ngx.log(ngx.INFO, '[cron] finished ' .. timer.id .. ' job  ' .. job_id)

  dict:delete(job_id)
end

crontab.shutdown = function()
  crontab.halt()
  crontab.flush()
end

crontab.halt = function()
  dict:flush_all()
  dict:flush_expired()
end

crontab.reset = function()
  ngx.log(ngx.INFO, 'crontab reset')
  crontab.halt()
  crontab.initialize()
end

crontab.stats = function()
  return {
    timers   = #TIMERS,
    jobs     = get_jobs()
  }
end

return crontab
