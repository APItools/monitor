local resty_lock = require "resty.lock"

local M = {}
M.around = function(name, func, ...)
  local lock = assert(resty_lock:new('locks'))
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

M.wrapper = function(name, fun)
  return function(...)
    return M.around(name, fun, ...)
  end
end

return M
