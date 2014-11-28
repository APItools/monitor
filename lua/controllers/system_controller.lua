local h     = require 'controller_helpers'
local inspect = require 'inspect'
local System = require 'models.system'

local system = {
  skip_csrf = true,

  initialize = function(params)
    System.initialize()
    h.send_json({status = 'ok'})
  end,

  log = function(params)
    ngx.say("starting stream of " .. System.logfile)

    ngx.flush(true)

    System.log(function(line)
      ngx.say(line)
      ngx.flush(true)
    end)
    ngx.exit(200)
  end,

  reset = function(params)
    System.reset()
    h.send_json({status = 'ok'})
  end,

  cron_flush = function(params)
    System.cron_flush()
    h.send_json({status = 'ok'})
  end,

  cron_trigger = function(params)
    ngx.timer.at(0, System.cron_flush)
    h.send_json({status = 'scheduled'})
  end,

  cron_stats = function()
    h.send_json({ cron_stats = System.cron_stats() })
  end,

  metrics = function(params)
    local Metric = require 'models.metric'
    h.send_json(Metric:delete_indices())
  end,

  status = function()
    h.send_json(System.status())
  end,

  timer = function(params)
    local timer_id = params.timer_id

    System.run_timer(timer_id)

    h.send_json({ status = 'ok', timer_id = timer_id })
  end
}

return system
