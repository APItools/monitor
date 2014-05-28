local inspect  = require 'inspect'
local m        = require 'model_helpers'
local fn       = require 'functional'
local jor      = require 'jor'
local statsd   = require 'statsd_wrapper'
local Queue    = require 'shared_queue'

local map = fn.map
local is_table = fn.is(type, 'table')

local Model = {}
local Model_mt = {__index = Model}

Model.build_excluded_fields = function(...)
  -- converts array ... into a hash with elements of t as keys and true
  -- as value. Jor needs this format
  local res = {}
  for i,v in ipairs({...}) do
     res[v] = true
  end
  return res
end

function Model:check_dots(obj, model, method_name)
  if is_table(obj) and
    (obj == model or (getmetatable(obj) or {}).__index == model) then
    return
  end
  error('Expected a model. Check that you wrote YourModel:' .. method_name ..
        '(...) and not YourModel.' .. method_name .. '(...)')
end

function Model:new(tbl)
  Model:check_dots(self, Model)
  return setmetatable(tbl or {}, Model_mt)
end

-- Implement methods using model_helper
for name, fun in pairs(m) do
  Model[name] = function(self, ...)      -- Model.find = function(self, ...)
    Model:check_dots(self, Model, name)  --   Model:check_dots(self, Model, 'find')
    return fun(self.collection, ...)      --   return m.find(self.collection, ...)
  end                                    -- end
end

function Model:create(values, options)
  Model:check_dots(self, Model, 'create')
  options = options or {}

  if not is_table(options.excluded_fields_to_index) then
    options.excluded_fields_to_index = self.excluded_fields_to_index or {}
  end

  return m.create(self.collection, values, options)
end

function Model:update(selector, content, options)
  Model:check_dots(self, Model, 'update')
  options = options or {}

  if not is_table(options.excluded_fields_to_index) then
    options.excluded_fields_to_index = self.excluded_fields_to_index or {}
  end

  return m.update(self.collection, selector, content ,options)
end

-- it creates the object if it does not have _id attribute
function Model:create_or_update(object)
  Model:check_dots(self, Model, 'create_or_update')

  if object._id then -- update
    return self:update({_id = object._id}, object)
  else
    return self:create(object)
  end
end

function Model:one(id, error_msg)
  assert(error_msg)

  Model:check_dots(self, Model, 'one')

  id = tonumber(id)

  return self:find_or_error(id, error_msg)
end

-- it saves first parameter asynchronously in timer
-- it locks a counter untill the object is saved
-- the second parameter is a function and if passed,
  -- it will be called inside the lock

function Model:async_save(object, fn)
  Model:check_dots(self, Model, 'async_save')

  jor:lock('async')

  local result = { true }

  if fn then
    result = {pcall(fn)}
  end

  local ok, err = pcall(function() self:enqueue(object) end)

  if not ok then
    err = ngx.re.match(err, ":([^:]+?)$")
    local msg = "inserting to " .. self.collection .. " failed because :" ..  err[1]
    local Event = require 'models.event'
    Event:create({channel = 'syslog', level = 'error', msg = msg })
    jor:unlock('async')
  end

  local ok = table.remove(result, 1)
  if ok then
    return unpack(result)
  else
    error(result[1])
  end
end

function Model:enqueue(object)
  Model:check_dots(self, Model, 'enqueue')
  local queue = Queue:new(self.collection)
  return queue:push(object)
end

function Model:consume()
  Model:check_dots(self, Model, 'consume')

  local collection = self.collection

  local num = 0
  local queue = Queue:new(collection)
  ngx.log(ngx.INFO, 'queue ' .. collection .. '  size: ' .. queue:size())

  local object = queue:pop()

  while object do
    num = 1 + num
    self:create_or_update(object)

    jor:unlock('async')

    object = queue:pop()
  end

  queue:free()

  ngx.log(ngx.INFO, 'consumed ' .. num .. ' ' .. collection)

  return num
end

return Model
