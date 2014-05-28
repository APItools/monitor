-- return the middleware
local Event = require 'models.event'

return function(req, res)
  if res.status == 500 then
    Event:create({channel = "middleware", level = "info",
                  msg = "nnnnnnnnooooooope"})
  end
end
