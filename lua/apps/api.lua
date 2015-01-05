local error_handler  = require 'error_handler'
local router_lib     = require 'router'
local statsd         = require 'statsd_wrapper'
local resource       = require 'resource_helpers'
local csrf           = require 'csrf'

local router = router_lib.new()

local controller_name, action_name -- if these two are filled, statsd is also saved for the controller.action

local function array_contains_object(table, object)
  for _,val in ipairs(table) do
    if val == object then return true end
  end
end

local function skip_csrf(config)
  if config == true then return config end
  return type(config) == 'table' and array_contains_object(config, action_name)
end

local function check_csrf(controller)
  local enabled = csrf.enabled and not skip_csrf(controller.skip_csrf)
  local method = ngx.req.get_method()

  if enabled and (method == 'POST' or method == 'PUT' or method == 'PATCH') then
    local ok, msg = csrf.validate_token(ngx.var.http_x_xsrf_token)
    if not ok then
      ngx.status = 403
      ngx.say(msg)
    end
    return ok
  else
    return true
  end
end

local r = function(route)
  local c, a = route:match('^(.+)%.(.+)$')
  if not c or not a then error('could not parse controller & action from route: ' .. route) end

  return function(...)
    controller_name = c
    action_name = a

    local controller = require('controllers.' .. controller_name .. '_controller')
    local action = controller[action_name]

    if check_csrf(controller) then
      return action(...)
    end
  end
end

local make_crud = function(base_url, resource_name)
  router:get( base_url, function(params)
    controller, action = resource_name, 'index'
    resource.index(resource_name, params)
  end)
  router:get( base_url .. 'count', function(params)
    controller, action = resource_name, 'count'
    resource.count(resource_name, params)
  end)
  router:post( base_url         , function(params)
    controller, action = resource_name, 'create'
    resource.create(resource_name, params)
  end)
  router:get( base_url .. ':id', function(params)
    controller, action = resource_name, 'show'
    resource.show(resource_name, params)
  end)
  router:post( base_url .. ':id', function(params)
    controller, action = resource_name, 'update'
    resource.update(resource_name, params)
  end)
  router:delete( base_url .. ':id', function(params)
    controller, action = resource_name, 'delete'
    resource.delete(resource_name, params)
  end)
end

router:get(    '/api_docs/proxy'                             , r('api_docs.proxy'))
router:get(    '/api/services'                               , r('services.index'))
router:get(    '/api/services/:id'                           , r('services.show'))
router:post(   '/api/services'                               , r('services.create'))
router:post(   '/api/services/:id'                           , r('services.update'))
router:delete( '/api/services/:id'                           , r('services.delete'))

router:get(    '/api/services/:service_id/docs'              , r('docs.show'))
router:head(   '/api/services/:service_id/docs'              , r('docs.show'))
router:get(    '/api/services/:service_id/docs/download'     , r('docs.download'))
router:get(    '/api/services/:service_id/path_autocomplete' , r('docs.get_path_autocomplete'))
router:get(    '/api/services/:service_id/operation'         , r('docs.get_operation'))
router:get(    '/api/services/:service_id/used_methods'      , r('docs.get_used_methods'))

router:get(    '/api/services/:service_id/pipeline'          , r('pipelines.show'))
router:post(   '/api/services/:service_id/pipeline'          , r('pipelines.update'))

router:get(    '/api/traces'                                 , r('traces.index'))
router:get(    '/api/traces/:uuid/find'                      , r('traces.uuid'))
router:get(    '/api/traces/search'                          , r('traces.search'))
router:get(    '/api/traces/search_for_index'                , r('traces.search_for_index'))
router:get(    '/api/traces/last_id'                         , r('traces.last_id'))
router:post(   '/api/traces'                                 , r('traces.create'))
router:delete( '/api/traces/:id'                             , r('traces.delete'))
router:delete( '/api/traces/all'                             , r('traces.delete_all'))
router:get(    '/api/traces/:id'                             , r('traces.show'))
router:delete( '/api/traces/expire'                          , r('traces.expire'))
router:post(   '/api/traces/:id/redo'                        , r('traces.redo'))
router:post(   '/api/traces/:id/star'                        , r('traces.star'))
router:delete( '/api/traces/:id/star'                        , r('traces.unstar'))
router:get(    '/api/traces/saved'                           , r('traces.index_saved'))

router:get(    '/api/traces/count'                           , r('traces.count'))

router:get(    '/api/services/:service_id/traces'            , r('service_traces.index'))
router:get(    '/api/services/:service_id/traces/search'     , r('service_traces.search'))
router:get(    '/api/services/:service_id/traces/search_for_index'     , r('service_traces.search_for_index'))
router:get(    '/api/services/:service_id/traces/count'      , r('service_traces.count'))
router:post(   '/api/services/:service_id/traces/:id/redo'   , r('traces.redo'))
router:delete( '/api/services/:service_id/traces/:id'        , r('traces.delete'))
router:delete( '/api/services/:service_id/traces/all'        , r('service_traces.delete_all'))

router:get(    '/api/services/:service_id/bucket'            , r('service_buckets.show '))
router:delete( '/api/services/:service_id/bucket'            , r('service_buckets.delete '))

router:get(    '/api/services/:service_id/mw_buckets'        , r('middleware_buckets.index '))
router:delete( '/api/services/:service_id/mw_buckets/:uuid'  , r('middleware_buckets.delete '))

router:get(    '/api/services/:service_id/console/:uuid'     , r('console.index'))

router:get(    '/api/versions/'                              , r('versions.index'))
router:get(    '/api/versions/:id'                           , r('versions.show'))
router:delete( '/api/versions/:id'                           , r('versions.delete'))

router:get(    '/api/services/:service_id/pipeline/versions' , r('versions.pipelines'))

router:get(    '/api/services/:service_id/stats/analytics'   , r('stats.service_chart'))
router:get(    '/api/services/:service_id/stats/dashboard'   , r('stats.dashboard'))
router:get(    '/api/stats/metrics'                          , r('stats.metrics'))
router:get(    '/api/stats/analytics'                        , r('stats.aggregated_chart'))

router:get(    '/api/events'                                 , r('events.index'))
router:delete( '/api/events/expire'                          , r('events.expire'))
router:get(    '/api/events/:id'                             , r('events.show'))
router:delete( '/api/events/:id'                             , r('events.delete'))

router:delete( '/api/events/all'                             , r('events.delete_all'))

router:post(   '/api/events/:id/star'                        , r('events.star'))
router:delete( '/api/events/:id/star'                        , r('events.unstar'))
router:get(    '/api/events/search/'                         , r('events.search'))
router:get(    '/api/events/count'                           , r('events.count'))
router:get(    '/api/events/process_pending'                 , r('events.force_process'))

router:get(    '/api/event_observers'                        , r('event_observers.index'))
router:get(    '/api/event_observers/:id'                    , r('event_observers.show'))
router:post(   '/api/event_observers'                        , r('event_observers.create'))
router:post(   '/api/event_observers/:id'                    , r('event_observers.update'))
router:delete( '/api/event_observers/:id'                    , r('event_observers.delete'))

router:get(    '/api/middlewares/:uuid'                      , r('middlewares.show'))

router:get(    '/api/middleware_specs'                       , r('middleware_specs.index'))
router:get(    '/api/middleware_specs/:id'                   , r('middleware_specs.show'))
router:post(   '/api/middleware_specs'                       , r('middleware_specs.create'))
router:post(   '/api/middleware_specs/:id'                   , r('middleware_specs.update'))
router:delete( '/api/middleware_specs/:id'                   , r('middleware_specs.delete'))

router:get(    '/api/services/:service_id/call'              , r('http_caller.do_call'))

router:post(   '/api/system/initialize'                      , r('system.initialize'))
router:post(   '/api/system/reset'                           , r('system.reset'))

router:post(   '/api/system/clean_metrics'                   , r('system.metrics'))
router:get(    '/api/system/log'                             , r('system.log'))
router:get(    '/api/system/cron/stats'                      , r('system.cron_stats'))
router:post(   '/api/system/cron/flush'                      , r('system.cron_flush'))
router:post(   '/api/system/cron'                            , r('system.cron_trigger')) -- async
router:post(   '/api/system/cron/:timer_id'                  , r('system.timer'))
router:get(    '/api/system/status'                          , r('system.status'))

router:get(    '/api/config'                                 , r('config.show'))
router:post(   '/api/config'                                 , r('config.update'))
router:delete( '/api/config'                                 , r('config.clear'))

-- v1
router:get(    '/api/get_slug_name'                          , r('config.get_slug_name'))
router:post(   '/api/set_slug_name'                          , r('config.set_slug_name'))
-- v2
router:get(    '/api/slug_name'                              , r('config.get_slug_name'))
router:post(   '/api/slug_name'                              , r('config.set_slug_name'))

router:get(    '/api/services/:service_id/dashboards/'       , r('dashboards.index'))
router:post(   '/api/services/:service_id/dashboards/'       , r('dashboards.create'))
router:get(    '/api/services/:service_id/dashboards/:id'    , r('dashboards.show'))
router:post(   '/api/services/:service_id/dashboards/:id'    , r('dashboards.update'))
router:delete( '/api/services/:service_id/dashboards/:id'    , r('dashboards.delete'))

router:get(    '/api/brain'                                  , r('brain.url'))
router:post(   '/api/brain/report'                           , r('brain.report'))
router:post(   '/api/brain/register'                         , r('brain.register'))
router:post(   '/api/brain/link'                             , r('brain.link'))
router:post(   '/api/brain/unlink'                           , r('brain.unlink'))

router:get(    '/api/brain/middleware_specs/search/'         , r('brain_middleware_specs.search'))
router:get(    '/api/brain/middleware_specs/:id/'            , r('brain_middleware_specs.show'))

router:get(    '/api/jor/dump/export'                        , r('backups.export'))
router:post(   '/api/jor/dump/import'                        , r('backups.import'))
router:get(    '/api/redis/stats'                            , r('redis.stats'))
router:get(    '/api/redis/keys'                             , r('redis.keys'))

make_crud('/api/filters/traces/', 'filters-traces')
make_crud('/api/filters/specs/', 'filters-specs')
make_crud('/api/filters/analytics/', 'filters-analytics')
make_crud('/api/filters/events/', 'filters-events')

make_crud('/api/metrics/', 'metrics')
make_crud('/api/autoswagger/', 'autoswagger_hosts')

local method = ngx.req.get_method():lower()

local ok, route_found = error_handler.execute_and_report(function()
  return router:execute(method, ngx.var.uri, ngx.req.get_uri_args())
end)

controller_name = controller_name or "unknown"
action_name = action_name or "unknown"
statsd.time('api.request.' .. controller_name .. '.' .. action_name, ngx.now() - ngx.req.start_time())

if ok and not route_found then
  ngx.status = ngx.HTTP_NOT_FOUND
  ngx.log(0, 'not found: ' .. ngx.var.uri)
end
