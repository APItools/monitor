local h          = require 'controller_helpers'
local analytics  = require 'analytics'
local Trace      = require 'models.trace'
local Metric     = require 'models.metric'

return {

  service_chart = function(params)
    assert(params.service_id, 'Need a service id')

    local query = h.decode_json_or_error(params.query)
    query.service_id = tonumber(params.service_id)

    h.send_json(analytics.get_service_chart(query))
  end,

  aggregated_chart = function(params)
    local query = h.decode_json_or_error(params.query)
    h.send_json(analytics.get_aggregated_chart(query))
  end,

  metrics = function(params)
    local response, len = {}, 0
    for name, metric_type in pairs(Metric:get_names_and_types()) do
      len = len + 1
      response[len] = { key = name, ['type'] = metric_type, desc = name }
    end

    h.send_json(response)
  end,

  dashboard = function(params)

    assert(params.service_id, 'Need a service id')

    local service_id = tonumber(params.service_id)

    local status = { status = 'ok', message = 'No errors in the last 30 minutes' }

    local now = ngx.time()
    local half_an_hour, ten_seconds = 1800, 10
    local one_hour_ago, half_an_hour_ago = now - 3600, now - half_an_hour

    local errors_detected = assert(Trace:count({
      service_id  = service_id,
      res         = { status = { ["$gte"] = 500 } },
      _created_at = { ["$gte"] = half_an_hour_ago, ["$lte"] = now }
    }))

    if errors_detected > 0 then
      status = { status = 'errors', message = tostring(errors_detected) .. ' error(s) in the last 30 minutes' }
    end

    local requests_in_last_hour = assert(Trace:count({
      service_id  = service_id,
      _created_at = { ["$gte"] = one_hour_ago, ["$lte"] = now }
    }))

    local chart = analytics.get_service_chart({
      metrics      = {"*","*","*"},
      service_id   = service_id,
      projections  = {"count"},
      range        = {["end"] = "now", start = half_an_hour, granularity = ten_seconds},
      metric       = "status",
      group_by     = {false,false,true}
    })

    h.send_json({
      status = status,
      rate   = requests_in_last_hour,
      chart  = chart,
    })
  end
}
