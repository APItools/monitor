local h = require 'controller_helpers'
local m = require 'model_helpers'

local Config = require 'models.config'

local config = {
  skip_csrf = {'set_slug_name', 'clear'},

  show = function(params)
    h.send_json(Config.get())
  end,

  update = function(params)
    h.send_json(Config:update_except_slug_name(h.request_json()))
  end,

  clear = function(params)
    h.send_json(Config.reset())
  end,

  get_slug_name = function(params)
    h.send_json({slug_name = Config.get_slug_name()})
  end,

  set_slug_name = function(params)
    local body = h.request_json()
    h.send_json(Config.set_slug_name(body.slug_name))
  end,

}

return config
