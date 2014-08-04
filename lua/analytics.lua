local Metric   = require 'models.metric'
local Trace    = require 'models.trace'
local inspect  = require 'inspect'

local analytics = {
  _VERSION = "0.2.0"
}


local OPERATORS = {}
for op in ("$gt $gte $lt $lte"):gmatch("%$%w+") do OPERATORS[op] = 'numeric' end
for op in ("$in $not"):gmatch("%$%w+")          do OPERATORS[op] = 'set' end

local function isPrimitive(value)
  local tv = type(value)
  return tv == 'string' or tv == 'number' or tv == 'boolean'
end

local function isEmpty(tbl)
  return next(tbl) == nil
end

local function isPositiveInteger(n)
  return type(n) == 'number' and n > 0 and math.floor(n) == n
end

local function isArrayOfPrimitives(tbl)
  if type(tbl) ~= 'table' then return false end
  if isEmpty(tbl) then return false end

  local maximum, count = 0, 0
  for k, v in pairs(tbl) do
    if not isPositiveInteger(k) or not isPrimitive(v) then
      return false
    end
    maximum, count = math.max(maximum, k), count + 1
  end
  return count == maximum
end

local function isNumericOperatorsTable(tbl)
  for k,_ in pairs(tbl) do
    if not OPERATORS[k] == 'numeric' then return false end
  end
  return true
end

local function isSetOperatorsTable(tbl)
  for k,_ in pairs(tbl) do
    if not OPERATORS[k] == 'set' then return false end
  end
  return true
end

local function isOperatorsTable(tbl)
  return isNumericOperatorsTable(tbl) or isSetOperatorsTable(tbl)
end

local function level_to_string(level)
  if type(level) ~= 'table' then return level end

  if isNumericOperatorsTable(level) then
    local buffer           = {}
    local lt, lte, gt, gte = level['$lt'], level['$lte'], level['$gt'], level['$gte']
    local legend           = {[lt] = '<', [lte] = '<=', [gt] = '>', [gte] = '>='}

    for value, symbol in pairs(legend) do
      buffer[#buffer + 1] = symbol .. ' ' .. value
    end
    return '(' .. table.concat(buffer, ', ') .. ')'
  elseif level['$in'] then
    return '(' .. table.concat(level['$in'], ', ') .. ')'
  elseif level['$not'] then
    return 'NOT (' .. table.concat(level['$not'], ', ') .. ')'
  else
    error('Could not parse level table')
  end
end

local function normalize_time(epoch, granularity_in_sec)
  return math.floor(epoch / granularity_in_sec) * granularity_in_sec
end

local function normalize_period(start_time_epoch, end_time_epoch, granularity_in_sec)
  if end_time_epoch == "now" then
    end_time_epoch   = ngx.time()
    start_time_epoch = end_time_epoch - start_time_epoch
  end

  -- force granularity to be aligned with metric compactation
  local compacted_granularity = Metric:get_granularity_for(start_time_epoch)
  if compacted_granularity then granularity_in_sec = math.max(compacted_granularity, granularity_in_sec) end

  start_time_epoch = normalize_time(start_time_epoch, granularity_in_sec)
  end_time_epoch   = normalize_time(end_time_epoch, granularity_in_sec) + granularity_in_sec

  return start_time_epoch, end_time_epoch, granularity_in_sec
end

local function array_rep(size, value)
  local result = {}
  for i=1,size do result[i] = value end
  return result
end

-- transforms {'count', 'last'} (or nil) in {count=true, last=true}
local function parse_projections(projections)
  if type(projections) ~= 'table' or #projections == 0 then
    return { count = true, last = true, avg = true, p50 = true, p80 = true,
               p90 = true, p95 = true, p99 = true, max = true, min = true }
  end

  local result = {}
  for _, p in ipairs(projections) do result[p] = true end
  return result
end

local function parse_group_by(group_by)
  group_by = group_by or {}
  return {
    method   = not group_by[1],
    paths    = not group_by[2],
    statuses = not group_by[3]
  }
end

local function get_time_index(time, range_start, range_end, granularity)
  if time >= range_start and time <= range_end then
    return math.floor((time - range_start) / granularity) + 1
  end
end

local function cleanup_lines(src_lines)
  -- transfroms src_lines (a hash) into lines (an array)
  local lines,len = {},0
  for _,line in pairs(src_lines) do
    line.nums = nil
    line.maxs = nil
    line.mins = nil
    line.sums = nil

    len = len + 1
    lines[len] = line
  end
  return lines
end

local function get_line_key(service_id, method, generic_path, status, projection, group_by)
  -- ignore service_id
  if group_by.method   or not method       then method       = '*' end
  if group_by.paths    or not generic_path then generic_path = '*' end
  if group_by.statuses or not status       then status       = '*' end
  return table.concat({method, generic_path, status, projection}, "|")
end

local function get_line_title(service_id, method, generic_path, status, projection, group_by)
  local buffer = {}
  -- ignore service_id
  if not group_by.method   and method       then buffer[#buffer + 1] = level_to_string(method)       end
  if not group_by.paths    and generic_path then buffer[#buffer + 1] = level_to_string(generic_path) end
  if not group_by.statuses and status       then buffer[#buffer + 1] = level_to_string(status)       end
  buffer[#buffer + 1] = projection
  return table.concat(buffer, " ")
end

local function extract(metrics, range_start, range_end, granularity, projections, group_by)
  local lines       = {}
  local num_points = get_time_index(range_end, range_start, range_end, granularity) - 1
  if not metrics or #metrics == 0 then
    lines['No data'] = {
      metric = 'No data',
      empty = true,
      num_el = 0,
      sum_el = 0,
      data   = array_rep(num_points, 0)
    }
  else
    for _, doc in ipairs(metrics) do
      for projection, amount in pairs(doc.projections) do

        if projections[projection] then
          local ind = get_time_index(doc._created_at, range_start, range_end, granularity)

          local key = get_line_key(doc.service_id, doc.method, doc.generic_path, doc.status, projection, group_by)

          lines[key] = lines[key] or {
            metric = get_line_title(doc.service_id, doc.method, doc.generic_path, doc.status, projection, group_by),
            num_el = 0,
            sum_el = 0,
            data   = array_rep(num_points, 0),
            sums   = array_rep(num_points, 0),
            nums   = array_rep(num_points, 0),
            mins   = {},
            maxs   = {}
          }

          local line = lines[key]

          if     projection == 'min' then
            line.mins[ind] = math.min(line.mins[ind] or math.huge, amount)
            line.data[ind] = line.mins[ind]
          elseif projection == 'max' then
            line.maxs[ind] = math.max(line.maxs[ind] or -math.huge, amount)
            line.data[ind] = line.maxs[ind]
          else
            line.sums[ind] = line.sums[ind] + amount
            line.nums[ind] = line.nums[ind] + 1
            if projection == 'count' then
              line.data[ind] = line.sums[ind]
            else -- average all the things
              line.data[ind] = line.sums[ind] / line.nums[ind]
            end
          end

          line.num_el    = line.num_el + 1
          line.sum_el    = line.sum_el + amount
        end
      end
    end
  end

  return cleanup_lines(lines)
end

local function parse_metric(m)
  if type(m) == 'table' then
    if isArrayOfPrimitives(m) then m = {["$in"] = m} end
  end
  if m == "*" then m = {} end
  return m
end

local function validate_type(value, name, typename)
  if type(value) ~= typename then
    error(name ..' must be of type ' .. typename .. ', not ' .. type(value))
  end
end

local function validate_range(range)
  validate_type(range,       'query.range', 'table')
  validate_type(range.start, 'query.range.start', 'number')
  if range['end'] ~= 'now' then
    validate_type(range['end'], 'query.range.end', 'number')
  end
  validate_type(range.granularity, 'query.range.granularity', 'number')
end

local function validate_projections(projections)
  validate_type(projections, 'query.projections', 'table')
  assert(#projections > 0, 'query.projections must have at least one element')
  for i,projection in ipairs(projections) do
    validate_type(projection, 'query.projections['..tostring(i)..']', 'string')
  end
end

local function validate_metric(metric)
  validate_type(metric, 'query.metric', 'string')
end

local function validate_group_by(group_by)
  validate_type(group_by, 'query.group_by', 'table')
  assert(#group_by > 0, 'query.group_by must have at least one element')
  for i,g in ipairs(group_by) do
    validate_type(g, 'query.group_by['..tostring(i)..']', 'boolean')
  end
end

local function validate_numeric_or_nil(value, name)
  if value ~= nil and type(value) ~= 'number' then
    error('Expected ' .. name .. ' to be a number. Was ' .. tostring(value))
  end
end

local function validate_primitive_array_or_nil(value, name)
  if value ~= nil and not isArrayOfPrimitives(value) then
    error('Expected ' .. name .. ' to be an array of primitives. Was ' .. tostring(value))
  end
end

local function validate_level(level)
  if type(m) == 'table' then
    if isArrayOfPrimitives(m) then return end -- arrays = ok

    if isOperatorsTable(m) then
      validate_numeric_or_nil(level['$lt'],  '$lt')
      validate_numeric_or_nil(level['$lte'], '$lte')
      validate_numeric_or_nil(level['$gt'],  '$gt')
      validate_numeric_or_nil(level['$gte'], '$gte')
      validate_primitive_array_or_nil(level['$in'], '$in')
      validate_primitive_array_or_nil(level['$not'], '$not')
      return -- operators ok
    end
    error('Expecting an operators table or array of values')
  end
end

local function validate_metrics(metrics)
  for i=1,3 do validate_level(metrics[i]) end
end

local function validate_aggregated_query(q)
  validate_type(q, 'query', 'table')
  validate_range(q.range)
  validate_projections(q.projections)
  validate_metric(q.metric)
  validate_metrics(q.metrics)
  validate_group_by(q.group_by)
end

local function validate_service_query(q) -- a service query is like an aggregated query, but with a service_id
  validate_aggregated_query(q)
  validate_type(q.service_id, 'service_id', 'number')
end

local function get_chart(q)
  local start = ngx.now()

  -- convert from query doc of analytics, to query doc of jor
  local range_start, range_end, granularity = normalize_period(q.range.start, q.range['end'], q.range.granularity)

  -- TODO: would be nice to extract these conditions to Metric model, because it also defines excluded fields
  local conditions = {
    _created_at   = {["$gte"]                                                              = range_start, ["$lt"]  = range_end},
    name          = q.metric,
    service_id    = q.service_id, -- number for the service chart, nil for the aggregated
    method        = parse_metric(q.metrics[1]),
    generic_path  = parse_metric(q.metrics[2]),
    status        = parse_metric(q.metrics[3])
  }

  local metrics = assert(Metric:all(conditions, {max_documents = -1}))

  local projections = parse_projections(q.projections)
  local group_by    = parse_group_by(q.group_by)

  local results = extract(metrics, range_start, range_end, granularity, projections, group_by)

  local normalized_query = {
    metrics = q.metrics,
    projections = q.projections,
    range = { start = range_start, ['end'] = range_end, granularity = granularity },
    metric = q.metric,
    group_by = q.group_by
  }

  -- now we need to filter out the projections
  return {
    results = results,
    normalized_query = normalized_query,
    elapsed_time = ngx.now()-start
  }
end

function analytics.get_service_chart(q)
  validate_service_query(q)
  return get_chart(q)
end

function analytics.get_aggregated_chart(q)
  validate_aggregated_query(q)
  return get_chart(q)
end

function analytics.get_brain_report(service_id)
  local minute                    = 60
  local period                    = 5*minute
  local period_start, period_end  = normalize_period(period, 'now', 5)
  local period_conditions         = {["$gte"]= period_start, ["$lt"]= period_end}
  local all_docs                  = { max_documents= -1 }

  local metrics_by_time = Metric:all({
    _created_at   = period_conditions,
    name          = 'time',
    service_id    = service_id
  }, all_docs)

  local total_response_time, request_count = 0, 0
  for _,metric in ipairs(metrics_by_time) do
    total_response_time = total_response_time + metric.projections.sum
    request_count       = request_count       + metric.projections.len
  end

  local erroneous_metrics = Metric:all({
    _created_at   = period_conditions,
    name          = 'status',
    service_id    = service_id,
    status        = {['$gte'] = 400}
  }, all_docs)

  local status, error_rate = 'ok', 0
  local error_count = 0

  for _,metric in ipairs(erroneous_metrics) do
    error_count = error_count + metric.projections.count
  end

  if error_count > 0 then
    status = 'errors'
    error_rate = request_count / error_count
  end

  local last_trace = Trace:find({service_id = service_id}, {reversed = true})
  local last_request_at = last_trace and os.date("!%Y-%m-%dT%TZ", last_trace._created_at)

  return {
    version              = analytics._VERSION,
    request_count        = request_count,
    error_count          = error_count,
    total_response_time  = total_response_time,
    last_request_at      = last_request_at,

    -- v1 fields
    rps                  = request_count / period,
    response_time        = total_response_time / period,
    status               = status,
    error_rate           = error_rate
  }
end

return analytics

