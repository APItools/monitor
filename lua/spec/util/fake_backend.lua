local backend = {}
backend.requests = {}
backend.send  = function(request)
  table.insert(backend.requests, request)
  backend.last_request = request
  return { status = 200 }
end
return backend
