local fake_backend = {}

function fake_backend.new()
  local backend = { requests = {} }

  backend.send = function(request)
    backend.requests[#backend.requests + 1] = request
    backend.last_request = request
    return { status = 200 }
  end

  return backend
end


return fake_backend
