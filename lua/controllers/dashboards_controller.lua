local h     = require 'controller_helpers'
local inspect = require 'inspect'
local m     = require 'model_helpers'

local collection = 'dashboards'
local dashboards = {
  show = function(params)
    local dashboard = m.find_or_error(collection,
                                      {service_id = tonumber(params.service_id),
                                       _id = tonumber(params.id)})
    h.send_json(dashboard)
  end,

  index = function(params)
    local dashboards = m.all(collection, {service_id = tonumber(params.service_id)})
    h.send_json(dashboards)
  end,

  create = function(params)
    local attributes = h.request_json() or {}
    attributes.service_id = tonumber(params.service_id)
    local dashboard = m.create(collection, attributes, { excluded_fields_to_index = {charts = true}})
    h.send_json(dashboard)
  end,

  update = function(params)
    local dashboard = m.update_or_error(collection,
                               {service_id = tonumber(params.service_id), _id = tonumber(params.id)},
                               h.request_json(), nil, {excluded_fields_to_index = {charts = true}})
    h.send_json(dashboard)
 end,

  delete = function(params)
    m.delete_or_error(collection,
                      {service_id = tonumber(params.service_id), _id = tonumber(params.id)})
  end
}

return dashboards
