-- Module to collect metrics.
local inspect     = require "inspect"
local Event       = require "models.event"
local Metric      = require "models.metric"
local shared_dict = require "shared_dict"

local collector = {}
collector._root = {}
collector._VERSION = "0.0.2"
collector._BUCKET_SECONDS = 5

local KEY_SEPARATOR  = "|"
local KEY_MATCH      = KEY_SEPARATOR .. "([^" .. KEY_SEPARATOR .. "]+)"
local LIST_SEPARATOR = ","
local LIST_MATCH     = LIST_SEPARATOR .. "([^" .. LIST_SEPARATOR .. "]+)"
local SET_KEY_SUFFIX = "0_set_id" -- the 0 is so it appears first when sorted alphabetically
local SET_KEY_LENGTH = #SET_KEY_SUFFIX + 1

collector._valid_metric_types = {
  count  = true,
  set    = true
}

collector._metrics = {
  hits   = "count",
  status = "count",
  time   = "set"
}

local function get_current_bucket()
  return math.floor(ngx.now() / collector._BUCKET_SECONDS) * collector._BUCKET_SECONDS
end

local function split_key(key)
  local words, len = {}, 0
  for field in key:gmatch(KEY_MATCH) do
    len = len + 1
    words[len] = field
  end
  return words
end

local function get_stats(array)
  table.sort(array)

  local len = #array
  local stats = {
    len = len,
    max = array[len],
    min = array[1],
    p50 = array[math.floor(len*0.5)+1],
    p80 = array[math.floor(len*0.8)+1],
    p90 = array[math.floor(len*0.9)+1],
    p95 = array[math.floor(len*0.95)+1],
    p99 = array[math.floor(len*0.99)+1]
  }

  stats.sum = 0.0
  for i, v in ipairs(array) do
    stats.sum = stats.sum + v
  end

  stats.avg = len == 0 and 0 or stats.sum/len

  return stats
end

local function reverse(a,b) return a > b end

-- transforms the string of keys { a, b, c } into a hash of values {a = x, b = y, c = z}, where
-- x,y,z are found on the dictionary. It also handles set-type keys, transforming then into arrays
local function parse_values(bucket_keys)
  table.sort(bucket_keys, reverse) -- make sure that entries representing the ids appear first
  local key_index = #bucket_keys
  local dict = ngx.shared.collector

  local values = {}

  while key_index > 0 do
    local key = bucket_keys[key_index]

    if key:sub(-SET_KEY_LENGTH) == KEY_SEPARATOR .. SET_KEY_SUFFIX then -- set key
      local set_key     = key:sub(1, #key - SET_KEY_LENGTH) -- the "real key" of the set, with the final id removed
      local set_key_len = #set_key
      local array, len  = {}, 0

      -- we can't use dict:get(key) to get the amount of keys because it could have changed (concurrency)
      -- instead, since the keys are sorted, we parse the following keys until we find one that doesn't start
      -- with the set_key or we reach the end of the bucket_keys array
      key_index = key_index - 1
      while key_index > 0 and bucket_keys[key_index]:sub(1, set_key_len) == set_key do
        local value = tonumber(dict:get(bucket_keys[key_index]))
        if value then -- value could have been erased (concurrency), so check before removing
          len = len + 1
          array[len] = value
        end
        key_index = key_index - 1
      end

      values[set_key] = array

    else -- count key
      values[key] = tonumber(dict:get(key))
      key_index = key_index - 1
    end
  end

  return values
end

local function delete_keys(keys)
  local dict = ngx.shared.collector
  for _,key in ipairs(keys) do
    dict:delete(key)
  end
end


local function flush_bucket(bucket, bucket_keys)
  local values = parse_values(bucket_keys)
  delete_keys(bucket_keys)

  for key, value in pairs(values) do
    local w     = split_key(key)

    local service_id,      metric_name, metric_type, method, generic_path, status =
          tonumber(w[2]),  w[3],        w[4],        w[5],   w[6],         tonumber(w[7])

    local doc = {
      _created_at   = tonumber(bucket),
      ['type']      = metric_type,
      name          = metric_name,
      service_id    = service_id,
      method        = method,
      generic_path  = generic_path,
      status        = status,
      granularity   = collector._BUCKET_SECONDS
    }

    if metric_type == "count" then
      doc.projections = { count = value }
    else -- metric_type == 'set'
      doc.projections = get_stats(value)
    end

    Event:create({
      _created_at  = doc._created_at,
      channel      = 'stats',
      level        = 'debug',
      msg          = tostring(collector._BUCKET_SECONDS) .. ' seconds have passed',
      stats        = doc
    })

    Metric:create(doc)
  end
end


------------------------------------------------------------

-- flush old buckets
function collector.flush()
  local current_bucket = get_current_bucket()
  local dict = ngx.shared.collector

  local old_buckets_keys = {}

  for _,key in ipairs(dict:get_keys(0)) do
    local key_bucket = key:match(KEY_MATCH)
    if key_bucket and tonumber(key_bucket) < current_bucket then
      old_buckets_keys[key_bucket] = old_buckets_keys[key_bucket] or {}
      local keys = old_buckets_keys[key_bucket]
      keys[#keys + 1] = key
    end
  end

  for bucket, bucket_keys in pairs(old_buckets_keys) do
    flush_bucket(bucket, bucket_keys)
  end
end

function collector.collect(service_id, metric_name, metric_type, list_labels, value)
  if (list_labels==nil or #list_labels==0) then
    return nil, "No metrics where passed"
  end

  if not collector._valid_metric_types[metric_type] then
    return nil, "Invalid metric type, must be: 'count' | 'set'"
  end

  local bucket = get_current_bucket()
  local key    = KEY_SEPARATOR .. table.concat({ bucket, service_id, metric_name, metric_type, unpack(list_labels) }, KEY_SEPARATOR)
  local dict   = ngx.shared.collector

  if metric_type == "set" then
    local item_id = shared_dict.incr('collector', key .. KEY_SEPARATOR .. SET_KEY_SUFFIX)
    local item_key = key .. KEY_SEPARATOR .. item_id
    dict:set(item_key, value)
  else -- metric_type == "count"
    shared_dict.incr('collector', key, value)
  end

end

return collector
