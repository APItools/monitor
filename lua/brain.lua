local Service    = require 'models.service'
local Pipeline   = require 'models.pipeline'
local Config     = require 'models.config'
local analytics  = require 'analytics'
local cjson      = require 'cjson'
local http       = require 'http'
local resty_http = require 'resty.http'

local ten_minutes, five_seconds = 60*10, 5

local Brain = {}

Brain.host = os.getenv("SLUG_BRAIN_HOST")
Brain.url = function(path)
  return Brain.host .. (path or '')
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

local get_encoded_slug_info = function()
  -- TODO: send different params when on premise
  local slug_info = { slug_id = 'some slug', account_name = 'some name' }
  return cjson.encode(slug_info)
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
  return assert(http.simple(options, body))
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

  if not slug_name then
    ngx.log(ngx.WARN, 'skipping brain report because there is no slug name')
    return
  end

  local report = { slug = slug_name, services = {} }

  local services = Service:all()
  for i, service in ipairs(services) do
    report.services[i] = extract_service(service)
  end

  return report
end

Brain.url = function(path)
  local host = os.getenv('SLUG_BRAIN_HOST')
  return host .. path
end

Brain.send_report = function(report)
  if report then
    local res = post_json_to_brain('/api/reports', {report = report})
    return {status = res.status, body = res.body, headers = res.headers}
  end
end

Brain.register = function()
  local res = post_json_to_brain('/api/register', get_encoded_slug_info())
  return cjson.decode(res.body)
end

Brain.configure  = function(config)
  -- FIXME: the request body will probably contain different info than register
  local res = post_json_to_brain('/api/configure', get_encoded_slug_info())
  return cjson.decode(res.body)
end

Brain.use_keys = function(key_pair)
  Config.update({ keys = key_pair })
end

return Brain
