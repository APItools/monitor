local resty_lock = require "resty.lock"

local lock = {}
lock.around = function(name, func, ...)
  local lock = resty_lock:new('locks')
  lock:lock(name)
  ngx.log(ngx.DEBUG, 'locking around ' .. name)
  local res = {pcall(func, ...) }
  local ok = table.remove(res, 1)
  lock:unlock()
  ngx.log(ngx.DEBUG, 'unlocked ' .. name)

  if ok then
    return unpack(res)
  else
    return nil, res[1]
  end
end

lock.wrapper = function(name, fun)
  return function(...)
    return lock.around(name, fun, ...)
  end
end

return lock
