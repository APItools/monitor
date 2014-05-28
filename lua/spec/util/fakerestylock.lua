local fakerestylock = {}

package.loaded['resty.lock'] = fakerestylock

function fakerestylock:new()
  return self
end

function fakerestylock:lock()
end

function fakerestylock:unlock()
end

return fakerestylock
