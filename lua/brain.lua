local Service    = require 'models.service'
local Pipeline   = require 'models.pipeline'
local Config     = require 'models.config'
local analytics  = require 'analytics'
local cjson      = require 'cjson'
local json      = require 'json'
local http       = require 'http'
local resty_http = require 'resty.http'

local inspect = require'inspect'

local ten_minutes, five_seconds = 60*10, 5

local Brain = {}

Brain.host = os.getenv("SLUG_BRAIN_HOST") or 'https://www.apitools.com'
Brain.url = function(path)
  return Brain.host .. (path or '')
end


local get = function(url, params)
  if params then
    url = string.format("%s%s?%s", Brain.host, url, ngx.encode_args(params))
  else
    url = string.format("%s%s", Brain.host, url)
  end
  print(url)
  return http.simple(url)
end


Brain.search_middleware = function(endpoint, query, per_page, page)
  return get('/api/middleware/search', {
      endpoint = endpoint,
      query = query,
      per_page = per_page,
      page = page

  })
end

Brain.show_middleware = function(id)
  return get(string.format('/api/middleware/%s', id))
end

local extract_middlewares = function(service)
  local pipeline = Pipeline:get(service)
  local middlewares = {}

  for uuid,middleware in pairs(pipeline.middlewares) do
    middlewares[uuid] = {
      name = middleware.name,
      spec_id = middleware.spec_id,
      active = middleware.active
    }
  end

  return middlewares
end

local extract_service = function(service)
  local endpoints = service.endpoints

  return {
    service_id   = service._id,
    name         = service.name,
    endpoint     = endpoints and endpoints[1].url,
    stats        = analytics.get_brain_report(service._id),
    middlewares  = extract_middlewares(service)
  }
end

local post_json_to_brain = function(path, payload)
  local body = cjson.encode(payload)
  local options = {
    url     = Brain.url(path),
    method  = 'POST',
    headers = {
      ['Accept']       = 'application/json',
      ['Content-Type'] = 'application/json'
    }
  }
  return http.simple(options, body)
end

Brain.trigger_report = function()
  local client = resty_http.new()
  return client:request_uri('http://' .. Config.localhost .. '/api/brain/report', { method = 'POST' })
end

Brain.async_trigger_report = function()
  ngx.timer.at(0, Brain.trigger_report)
end

Brain.make_report = function()
  local slug_name = Config.get_slug_name()
  local uuid      = Config.get_uuid()

  if not slug_name then
    ngx.log(ngx.WARN, 'skipping brain report because there is no slug name')
    return
  end

  local report = { version = 1,
                   uuid = uuid,
                   slug = slug_name,
                   services = {} }

  local services = Service:all()
  for i, service in ipairs(services) do
    report.services[i] = extract_service(service)
  end

  return report
end

Brain.send_report = function(report)
  if report then
    local res = post_json_to_brain('/api/reports', {report = report})
    return {status = res.status, body = res.body, headers = res.headers}
  end
end

Brain.register = function()
  local uuid = Config.get_uuid()
  local body, status = post_json_to_brain('/api/on_premise/register', {uuid = uuid})
  if http.is_success(status) then
    Config.set_slug_name(uuid)
    return json.decode(body)
  else
    error({status=status, message=body})
  end
end

Brain.link = function(key)
  if not key then error({status=400, message='key parameter missing'}) end

  local uuid = Config.get_uuid()

  local body, status = post_json_to_brain('/api/on_premise/link', {uuid = uuid, key = key})
  if http.is_success(status) then
    Config.set_link_key(key)
    ngx.log(0, inspect(body))
    return json.decode(body)
  else
    error({status=status, message=body})
  end
end

Brain.unlink = function()
  local uuid = Config.get_uuid()
  local key  = Config.get_link_key()

  if not key then
    error({status=400, message='the slug is not linked; can not unlink'})
  end

  local body, status = post_json_to_brain('/api/on_premise/unlink', {uuid = uuid, key = key})

  if http.is_success(status) then
    return json.decode(body)
  else
    error({status=status, message=body})
  end
end

return Brain
