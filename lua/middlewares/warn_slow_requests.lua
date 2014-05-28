-- return the middleware
local Event = require 'models.event'

return function(req, res, trace)
  if trace.time > 0.7 then
    Event:create({channel = "middleware", level = "info",
                  msg = "slow"})
  end
end
