
local MetricsMiddleware = {
  name = 'Measure X-Ratelimit-Remaining',
  author = {
    name = "3scale",
    github = "3scale"
  },
  description = "Allows measure custom metrics.",
  version = "0.1",
  code = [[
return function (request, next_middleware)
  local response = next_middleware()

  local remaining = response.headers['X-Ratelimit-Remaining']
  local limit = response.headers['X-Ratelimit-Limit']

  if limit and remaining then
    remaining = tonumber(remaining)
    limit = tonumber(limit)
    metric.set('ratelimit-used', limit - remaining)
    metric.set('ratelimit-remaining', remaining)
  end

  return response
end
]]
}
local AddingArgsMiddleware = {
  name = 'Change query params',
  author = {
    name = '3scale',
    github = '3scale'
  },
  description = 'Add or remove query parameters of the request.',
  version = '0.1',
  code = [[
return function (request, next_middleware)
  request.args.new_param = '1' -- adds new query param
  request.args.old_param = nil -- removes one if it was passed

  return next_middleware()
end
]]
}

local CachingMiddleware = {
  name = 'Response caching',
  author = {
    name = "3scale",
    github = "3scale"
  },
  version = "0.2",
  description = "Caches responses so you don't have to care about rate limiting!",
  code = [[
return function (request, next_middleware)
  -- initialize cache store

  local threshold = 60 -- 60 seconds
  local key = "cache=" .. request.uri_full

  if request.method == "GET" then
    local stored = bucket.middleware.get(key)
    if stored then
      local expires = stored.headers["X-Expires"]
      if expires and expires > time.now() then -- not expired yet
        -- send.event({channel = "cache", msg = "returned cached content", level = "debug", key = key, content = stored, expires = expires, now = time.now() })
        stored.headers["Expires"] = time.http(expires)
      end
      return stored
    end
    -- send.event({channel = "cache", msg = "NOT  cached content", level = "debug", key = key, content = stored, expires = expires, now = time.now() })
  end

  -- if content is not cached, do the real request & get response
  local response = next_middleware()

  if request.method == "GET" then
    local expires = time.now() + threshold
    response.headers["X-Expires"] = expires
    bucket.middleware.set(key, response, expires)
    -- send.event({channel = "cache", msg = "stored cached content", level = "debug", content = response })
  end

  return response
end
]]
}

local CorsMiddleware = {
  name = 'CORS header',
  author = {
    name = "3scale",
    github = "3scale"
  },
  description = "Cross origin resource sharing allows you to use API directly from the browser",
  version = "0.2",
  code = [[
return function (request, next_middleware)
  local response = next_middleware()
  response.headers["Access-Control-Allow-Origin"] = "*"
  return response
end
]]
}

local MailOn404s = {
  name = 'Alert on 404s',
  author = {
    name = "3scale",
    github = "3scale"
  },
  version = "0.1",
  description = "Sends a mail in case a call returns a 404",
  code = [[
return function (request, next_middleware)
  local five_mins = 60 * 5
  local res = next_middleware()
  local last_mail = bucket.middleware.get('last_mail')
  if res.status == 404  and (not last_mail or last_mail < time.now() - five_mins) then
    send.mail('YOUR-MAIL-HERE@gmail.com', "A 404 has ocurred", "a 404 error happened in " .. request.uri_full)
    bucket.middleware.set('last_mail', time.now())
  end
  return res
end
]]
}

local BasicAddKeys= {
  name = 'Add header',
  author = {
    name = "3scale",
    github = "3scale"
  },
  version = "0.1",

  description = "Adding header to a request",
  code = [[
return function (request, next_middleware)
  request.headers.authentication = 'this-is-my-key'
  return next_middleware()
end
]]

}

-- FIXME this will work as long as we don't use a "tracer", since the value of the request stored in the trace is
-- simply the last value it has when the pipeline ends executing.
-- If tracers are enabled, we must use something more sophisticated (like a special 'X-anonymize' header that the
-- tracer will read). But this is ok for now.
local Anonymizer={
  name = 'Anonymizer',
  author = {
    name = "3scale",
    github = "3scale"
  },
  version = "0.1",

  description = "removes sensitive information from the request before storing it",
  code = [[
return function (request, next_middleware)
  local res = next_middleware()
  request.headers.authentication = '**filtered**'
  return res
end
]]
}

-- FIXME this middleware is now unused, but was used in previous versions of APItools. Remove once we are
-- sure that we don't need it any more
local RemoveAcceptEncodingHeader={
  name = 'Accept-Encoding header remover',
  author = {
    name = "3scale",
    github = "3scale"
  },
  version = "0.1",
  description = "removes the `Accept-Encoding` header, deactivating response compression in most cases.",
  code = [[
return function (request, next_middleware)
  request.headers['Accept-Encoding'] = nil
  return next_middleware()
end
]]

}

local SetAcceptEncodingToIdentity={
  -- Warning: this name is used in services_controller.lua, too. Update in both
  name = 'Set Accept-Encoding = identity',
  author = {
    name = "3scale",
    github = "3scale"
  },
  version = "0.1",
  description = "sets the `Accept-Encoding` header to `identity`. This deactivates gzipped responses. This middleware is inserted by default in all new services.",
  code = [[
return function (request, next_middleware)
  request.headers['Accept-Encoding'] = 'identity'
  return next_middleware()
end
]]

}

return {
  CorsMiddleware,
  MetricsMiddleware,
  CachingMiddleware,
  MailOn404s,
  BasicAddKeys,
  Anonymizer,
  RemoveAcceptEncodingHeader,
  SetAcceptEncodingToIdentity,
  AddingArgsMiddleware
}
