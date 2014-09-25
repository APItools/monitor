local h        = require 'controller_helpers'
local inspect  = require 'inspect'
local Brain    = require 'brain'

local brain = {
  skip_csrf = true,

  url = function(params)
    h.send_json({host = Brain.host})
  end,

  report = function(params)
    local report = Brain.make_report()

    local res = Brain.send_report(report)

    h.send_json(res)
  end,

  register = function(params)
    local resp = Brain.register()
    h.send_json(resp)
  end,

  link = function(params)
    local json = h.request_json()
    local key = json.key
    h.send_json(Brain.link(key))
  end,

  unlink = function(params)
    h.send_json(Brain.unlink())
  end,

  configure = function(params)
    local configuration = h.request_json()
    local config = Brain.configure(configuration)

    h.send_json(config)
  end
}

return brain
