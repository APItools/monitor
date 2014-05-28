
local function copy(src)
  if type(src) ~= 'table' then return src end

  local result = {}
  for k,v in pairs(src) do result[k] = copy(v) end
  return result
end

return function(req, res, trace, middleware_name)
  if not trace           then error("Tracer middleware needs a trace") end
  if not middleware_name then error("Tracer middleware needs a middleware name") end

  trace.pipeline             = trace.pipeline or {}

  -- The request body is nil until it's asked for the first time.
  -- The following line requests it so that we don't have nil
  _ = req.body

  trace.pipeline[#trace.pipeline + 1] = {
    middleware = middleware_name,
    req = copy(req),
    res = copy(res)
  }
end
