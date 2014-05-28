local luajson = require 'json'
local Event = require 'models.event'

local shared_dict = {}

function shared_dict.set(dict_name, key, value)
  local ok, err = ngx.shared[dict_name]:set(tostring(key), luajson.encode(value), 0)
  if not ok then
    Event:create({
      channel   = 'syslog',
      level     = 'error',
      msg       = 'Error while setting shared dict: ' .. tostring(err),
      dict_name = dict_name,
      key       = key
    })
  end
end

function shared_dict.get(dict_name, key)
  local encoded = ngx.shared[dict_name]:get(tostring(key))
  if encoded then return luajson.decode(encoded) end
  -- else return nil
end

function shared_dict.clear(dict_name, key)
  ngx.shared[dict_name]:delete(tostring(key))
end

function shared_dict.reset()
  for _, dict in pairs(ngx.shared) do
    dict:flush_all()
    dict:flush_expired()
  end
end

-- Increments the value of key by amount
-- If key it not set, or its set to a non-number it sets it with amount
function shared_dict.incr(dict_name, key, amount)
  amount = amount or 1
  local dict   = ngx.shared[dict_name]
  dict:add(key, 0) -- makes sure that key has a previous value, so incr does not fail on nil
  local new_value = dict:incr(key, amount)
  if not new_value then -- previous value is not a number
    error("nxg.shared.dict[" .. dict_name .."] should be a number or nil, was " .. tostring(dict:get(key)))
  end
  return tonumber(new_value)
end

function shared_dict.to_table(dict_name)
  local result = {}
  local dict   = ngx.shared[dict_name]
  for _,key in ipairs(dict:get_keys()) do
    result[key] = dict:get(key)
  end
  return result
end

return shared_dict

