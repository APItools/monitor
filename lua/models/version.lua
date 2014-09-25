local Version = {}
Version.__index = Version

local function map(f, t)
  local res = {}
  for i,v in ipairs(t) do
    res[i] = f(v)
  end
  return res
end

local function split(str, delimiter)
  local result = {}
  delimiter = delimiter or " "
  for chunk in str:gmatch("[^".. delimiter .. "]+") do
    result[#result + 1] = chunk
  end
  return result
end


function Version:new(o_str)
  if o_str:find("[^%d.]") then
    return nil, "nope"
  end

  local obj =  map(function(x) return tonumber(x) end, split(o_str, "."))
  setmetatable(obj, Version)
  return obj
end

Version.__gt = function(a, b)
  for i=1,#a do
    if     tonumber(a[i]) >  tonumber(b[i])  then return true
    elseif tonumber(a[i]) <  tonumber(b[i])  then return false
    elseif tonumber(a[i]) == tonumber(b[i]) then
    else
      error("shouldn't be here")
    end
  end
  return false
end

Version.__lt = function(a, b)
  for i=1,#a do
    if     tonumber(a[i]) >  tonumber(b[i])  then return false
    elseif tonumber(a[i]) <  tonumber(b[i])  then return true
    elseif tonumber(a[i]) == tonumber(b[i]) then
    else
      error("shouldn't be here")
    end
  end
  return false
end

Version.__eq = function(a, b)
  for i=1,#a do
    if     tonumber(a[i]) >  tonumber(b[i])  then return false
    elseif tonumber(a[i]) <  tonumber(b[i])  then return false
    elseif tonumber(a[i]) == tonumber(b[i]) then
    else
      error("shouldn't be here")
    end
  end
  return true
end

Version.__tostring = function(self)
  return table.concat(self, ".")
end

return Version
