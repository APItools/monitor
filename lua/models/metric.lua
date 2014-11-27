local Model     = require 'model'
local m        = require 'model_helpers'
local jor      = require 'jor'

local Metric = Model:new()

Metric.collection = 'metrics'
Metric.excluded_fields_to_index = { _updated_at = true, type = true, projections = true }

local minute  = 60
local hour    = 60 * minute
local day     = 24 * hour
local week    = 7 * day
local month   = 30 * day
local year    = 365 * day

-- note: this table needs to be sorted from "older" to "newer"
Metric.compacting_rules = {
  { older_than = month,  granularity = week   },
  { older_than = week,   granularity = day    },
  { older_than = day,    granularity = hour   },
  { older_than = hour,   granularity = minute }
}

function Metric:get_names_and_types()
  local result = {}
  for _,metric in ipairs(Metric:all()) do
    result[metric.name] = metric['type']
  end
  return result
end

function Metric:default_granularity()
  local collector = require 'collector'
  return collector._BUCKET_SECONDS
end

local function to_key(metric)
  return table.concat({metric.service_id, metric.name, metric['type'], metric.method, metric.generic_path, metric.status}, "|")
end

local function compact_projections(metric)
  local projections = metric.projections
  if metric['type'] == 'count' then
    local count = 0
    for i=1, #projections do
      count = count + projections[i].count
    end
    metric.projections = {count = count}
  else -- metric.type == 'set'
    local len, sum, max, min = 0,0, -math.huge, math.huge
    local sum_p50, sum_p80, sum_p90, sum_p95, sum_p99 = 0,0,0,0,0
    for i=1, #projections do
      local pr = projections[i]

      if pr.max and pr.min then
        max, min = math.max(max, pr.max), math.min(min, pr.min)
        len = len + pr.len
        sum = sum + pr.sum
        sum_p50 = sum_p50 + pr.p50 * pr.len
        sum_p80 = sum_p80 + pr.p80 * pr.len
        sum_p90 = sum_p90 + pr.p90 * pr.len
        sum_p95 = sum_p95 + pr.p95 * pr.len
        sum_p99 = sum_p99 + pr.p99 * pr.len
      end
    end
    metric.projections = {
      len = len,
      max = max,
      min = min,
      sum = sum,
      avg = sum / len,
      p50 = sum_p50 / len,
      p80 = sum_p80 / len,
      p90 = sum_p90 / len,
      p95 = sum_p95 / len,
      p99 = sum_p99 / len
    }
  end
end

local function sort_by_created_at(a,b)
  return a._created_at and b._created_at and a._created_at < b._created_at
end

local function do_compact(dict, ids_to_delete)
  local keys= {}; for k,_ in pairs(dict) do keys[#keys+1] = k end

  ngx.log(ngx.NOTICE, '[metric] will compact ' .. #ids_to_delete .. ' metrics to ' .. #keys)

  for _,compacted_metric in pairs(dict) do
    compact_projections(compacted_metric)
    Metric:create(compacted_metric)
  end

  ngx.log(ngx.NOTICE, '[metric] done compacting ' .. #keys .. ' metrics')

  Metric:delete_ids(ids_to_delete)
end

function Metric:ids(conditions)
  return Metric:all(conditions, { only_ids = true, max_documents = -1 })
end

function Metric:delete_ids(ids)
  for _, m in ipairs(ids) do
    jor.driver:wipe_object(self.collection, m)
  end
  ngx.log(ngx.NOTICE, '[metric] deleted ' .. #ids .. ' metrics')
  return metrics
end

function Metric:delete(conditions)
  local metrics = Metric:ids(conditions)

  return Metric:delete_ids(metrics)
end

function Metric:delete_collection()
  Metric:delete()
  return m.delete_collection(self.collection)
end

function Metric:create(metric, options)
  local model = m.create(self.collection, metric, options)
  Metric:delete_indices(model._id)
  return model
end

function Metric:delete_indices(id)
  local conditions = { ['_id'] = id }
  local metrics = Metric:ids(conditions)
  for _, m in ipairs(metrics) do
    jor.driver:delete_reverse_indices(self.collection, m)
  end
end

function Metric:compact(start_epoch, end_epoch, granularity)
  local conditions = {}

  if start_epoch or end_epoch then conditions._created_at = {} end
  if start_epoch then conditions._created_at['$gte'] = start_epoch end
  if end_epoch   then conditions._created_at['$lte'] = end_epoch end

  conditions.granularity = granularity

  local metrics = Metric:all(conditions, { max_documents = -1 })
  ngx.log(ngx.NOTICE, '[metric] found ' .. #metrics .. ' metrics to compact')

  table.sort(metrics, sort_by_created_at)

  local dict, ids_to_delete, bucket, granularity

  for i=1, #metrics do
    local metric = metrics[i]
    local new_bucket, new_granularity = Metric:get_compacted_bucket(metric._created_at)

    if not new_bucket then
      ngx.log(ngx.WARN, "failed to compact metrics: " .. inspect(metric))
      break
    end

    if new_bucket ~= bucket then
      if dict then do_compact(dict, ids_to_delete) end

      dict, ids_to_delete = {}, {}
      bucket, granularity = new_bucket, new_granularity
    end

    -- If we reach a point where we get no more granularity, this means we're in today.
    -- No need to compact any further
    if not granularity then break end

    local key = to_key(metric)
    dict[key] = dict[key] or {
      service_id    = metric.service_id,
      name          = metric.name,
      ['type']      = metric['type'],
      method        = metric.method,
      status        = metric.status,
      generic_path  = metric.generic_path,

      _created_at   = new_bucket,
      granularity   = granularity,
      projections   = {}
    }

    local projections = dict[key].projections
    projections[#projections + 1] = metric.projections

    ids_to_delete[#ids_to_delete + 1] = metric._id
  end

  -- If the last metric is in the same batch as the previous ones, ensure that the last group of
  -- metrics is compacted
  if dict then do_compact(dict, ids_to_delete) end
end

function Metric:get_granularity_for(epoch)
  local rule, rule_time_limit, granularity
  local now = ngx.now()
  for i=1, #Metric.compacting_rules do
    rule            = Metric.compacting_rules[i]
    rule_time_limit = now - rule.older_than
    granularity     = rule.granularity

    if epoch <= rule_time_limit then
      return granularity
    end
  end
  -- nil granularity
end

function Metric:get_compacted_bucket(epoch)
  if not epoch then
    return nil, 'an epoch is needed'
  end

  local granularity = Metric:get_granularity_for(epoch)

  if granularity then
    epoch = math.floor(epoch / granularity) * granularity
  end

  return epoch, granularity -- notice that we might be returning a nil granularity here
end


return Metric
