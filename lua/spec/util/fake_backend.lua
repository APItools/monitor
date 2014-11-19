local backend = {}

local send = function(request)
  table.insert(backend.requests, request)
  backend.last_request = request
  return { status = 200 }
end

backend.reset = function()
  backend.requests = {}
  backend.last_request = ni
  backend.send = send

  return backend
end

return backend.reset()
