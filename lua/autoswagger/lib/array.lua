local PATH = (...):match("(.+%.)[^%.]+$") or ""
local straux   = require(PATH .. 'straux')

local ROOT_PATH = '/'
local DELIMITER = ROOT_PATH

local array = {}

local map = function(arr, f)
  local result, length = {}, 0
  for i=1, #arr do
    length = length + 1
    result[length] = f(arr[i])
  end
  return result
end

local choose = function(arr, f)
  local result, length = {}, 0
  for i=1, #arr do
    if f(arr[i]) then
      length = length + 1
      result[length] = arr[i]
    end
  end
  return result
end

local includes = function(arr, item)
  for i=1, #arr do
    if arr[i] == item then return true end
  end
  return false
end

local append = function(arr, other)
  local i = #arr
  for j=1, #other do
    i = i + 1
    arr[i] = other[j]
  end
  return arr
end

local sort = function(arr)
  table.sort(arr)
  return arr
end

local copy = function(arr)
  local result = {}
  for i=1, #arr do
    result[i] = arr[i]
  end
  return result
end

local untokenize = function(tokens)
  tokens = copy(tokens)
  local length = #tokens

  tokens[length] = nil -- remove EOL
  length = length - 1

  if length < 1 then return ROOT_PATH end

  local extension = tokens[length]

  if straux.begins_with(extension, '.') and length > 1 then
    tokens[length - 1] = tokens[length - 1] .. extension
    tokens[length] = nil
  end

  return ROOT_PATH .. table.concat(tokens, DELIMITER)
end

local array = {
  map         = map,
  includes    = includes,
  choose      = choose,
  sort        = sort,
  append      = append,
  copy        = copy,
  untokenize  = untokenize
}

return array
