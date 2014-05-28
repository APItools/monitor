return function(req, next_middleware, config)
  if req.headers then
    req.headers.Host = config.endpoint
  end
  local res = next_middleware()
  if res.headers then
    res.headers['Content-Length'] = #(res.body)
  end
  res.status = res.status or 200
  return res
end
