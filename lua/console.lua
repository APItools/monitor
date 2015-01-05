------------
--- Console
-- Like window.console. For Lua.
-- @module middleware

local inspect = require 'inspect'
local Event   = require 'models.event'
local Console = {}

--- Console
-- @type Console

local Console_methods = {}

local function log(self, level, ...)
  local args = {...}
  if #args == 1 then args = args[1] end
  if type(args) ~= 'string' then args = inspect(args) end

  local mt = getmetatable(self)

  Event:create({
    channel         = 'middleware',
    level           = level,
    service_id      = mt.service_id,
    middleware_uuid = tostring(mt.middleware_uuid),
    msg             = args
  })
end

local function sort_by_at(a,b) return a.at < b.at end

--- log
-- @param ... objects to be printed
-- @function console.log
function Console_methods:log(...)
  log(self, 'log', ...)
end

--- debug
-- @param ... objects to be printed
-- @function console.debug
function Console_methods:debug(...)
  log(self, 'debug', ...)
end

--- info
-- @param ... objects to be printed
-- @function console.info
function Console_methods:info(...)
  log(self, 'info', ...)
end

--- warn
-- @param ... objects to be printed
-- @function console.warn
function Console_methods:warn(...)
  log(self, 'warn', ...)
end

--- error
-- @param ... objects to be printed
-- @function console.error
function Console_methods:error(...)
  log(self, 'error', ...)
end

function Console_methods:get_latest_messages(since_when)
  local mt = getmetatable(self)

  local events = Event:all({
    channel         = 'middleware',
    service_id      = mt.service_id,
    middleware_uuid = mt.middleware_uuid,
    _created_at     = { ['$gt'] = since_when }
  }, {
    reversed = true
  })

  local messages = {}

  for i,event in ipairs(events) do
    messages[i] = {
      _id         = event._id,
      _created_at = event._created_at,
      level       = event.level,
      msg         = event.msg
    }
  end

  return messages
end

-----------------------

local function create_dot_method(cons, name)
  local method = Console_methods[name]
  if method then
    local f = function(...) return method(cons, ...) end
    rawset(cons, name, f)
    return f
  end
end

function Console.new(service_id, middleware_uuid)
  return setmetatable({}, {
    service_id      = tostring(service_id),
    middleware_uuid = middleware_uuid,
    __index         = create_dot_method
  })
end

return Console
