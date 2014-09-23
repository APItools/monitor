local Console = require 'console'
local h       = require 'controller_helpers'

local console_controller = {
  index = function(params)
    local service_id = params.service_id
    local uuid       = params.uuid
    local since_when = params.since
    local console    = Console.new(service_id, uuid)

    local messages   = console.get_latest_messages(tonumber(since_when))

    h.send_json(messages)
  end
}

return console_controller
