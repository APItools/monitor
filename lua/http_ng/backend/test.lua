local _M = {}

local function contains(expected, actual)
  if actual == expected then return true end
  local t1,t2 = type(actual), type(expected)
  if t1 ~= t2 then return false end

  if t1 == 'table' then
    for k,v in pairs(expected) do
      if not contains(actual[k], v) then return false end
    end
    return true
  end

  return false
end


_M.expectation = {}

_M.expectation.new = function(request)
  assert(request, 'needs expected request')
  local expectation = { request = request }

  -- chain function to add a response to expectation
  local mt = { respond_with = function(response) expectation.response = response end }

  return setmetatable(expectation, {__index = mt})
end

_M.expectation.match = function(expectation, request)
  return contains(expectation.request, request)
end

_M.new = function()
  local requests = {}
  local expectations = {}
  local backend = {}

  backend.expect = function(request)
    local expectation = _M.expectation.new(request)
    table.insert(expectations, expectation)
    return expectation
  end

  backend.send = function(request)
    local expectation = table.remove(expectations, 1)

    if not expectation then error('no expectation') end
    if not _M.expectation.match(expectation, request) then error('expectation does not match') end

    table.insert(requests, request)

    return expectation.response
  end

  backend.verify_no_outstanding_expectations = function()
    assert(#expectations == 0, 'has ' .. #expectations .. ' outstanding expectations')
  end

  return backend
end

return _M
