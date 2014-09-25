
local headers = {}
local headers_mt = {
  __newindex = function(table, key, value)
    rawset(table, headers.normalize_key(key), value)
    return value
  end,
  __index = function(table, key)
    return rawget(table, headers.normalize_key(key))
  end
}

local capitalize = function(string)
  local str = string:gsub('^%w', function(first) return first:upper() end)
  return str
end

headers.normalize_key = function(key)
  local parts = {}
  key:gsub('[^_-]+', function(part)
    table.insert(parts, capitalize(part))
  end)
  return table.concat(parts, '-')
end

headers.normalize = function(http_headers)
  http_headers = http_headers or {}

  local normalized = {}
  for k,v in pairs(http_headers) do
    normalized[headers.normalize_key(k)] = v
  end

  return normalized
end

headers.new = function(h)
  local normalized = assert(headers.normalize(h or {}))

  return setmetatable(normalized, headers_mt)
end

return headers
