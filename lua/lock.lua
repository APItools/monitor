local resty_lock = require "resty.lock"

local lock = {}
lock.around = function(name, func, ...)
  local lock = resty_lock:new('locks')
  lock:lock(name)
  ngx.log(ngx.DEBUG, 'locking around ' .. name)
  local ret, err = pcall(func, ...)
  lock:unlock()
  ngx.log(ngx.DEBUG, 'unlocked ' .. name)
  return ret, err
end

lock.wrapper = function(name, fun)
  return function(...)
    return lock.around(name, fun, ...)
  end
end

return lock
