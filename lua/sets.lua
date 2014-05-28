-- sets taken from http://www.phailed.me/2011/02/common-set-operations-in-lua/

module("sets", package.seeall)

sets.__VERSION = '0.0.1'

-- deepcompare taken from http://snippets.luacode.org/snippets/Deep_Comparison_of_Two_Values_3
function deepcompare(t1,t2,ignore_mt)
  local ty1 = type(t1)
  local ty2 = type(t2)
  if ty1 ~= ty2 then return false end
  -- non-table types can be directly compared
  if ty1 ~= 'table' and ty2 ~= 'table' then return t1 == t2 end
  -- as well as tables which have the metamethod __eq
  local mt = getmetatable(t1)
  if not ignore_mt and mt and mt.__eq then return t1 == t2 end
  for k1,v1 in pairs(t1) do
    local v2 = t2[k1]
    if v2 == nil or not deepcompare(v1,v2) then return false end
  end
  for k2,v2 in pairs(t2) do
    local v1 = t1[k2]
    if v1 == nil or not deepcompare(v1,v2) then return false end
  end
  return true
end

function find(a, tbl)
  if tbl==nil then
    return false
  else
	  --for _,a_ in ipairs(tbl) do if a_==a then return true end end
	  for _,a_ in ipairs(tbl) do if deepcompare(a_,a,true) then return true end end
	end
end

function union(a, b)
  local dict = {}
  for i=1,#a do dict[a[i]] = true end
  for i=1,#b do dict[b[i]] = true end

  local r, len = {}, 0
  for k in pairs(dict) do
    len = len + 1
    r[len] = k
  end

	return r
end

function intersection(a, b)
	local ret = {}
	for _,b_ in ipairs(b) do
		if find(b_,a) then table.insert(ret, b_) end
	end
	return ret
end

function difference(a, b)
	local ret = {}
	for _,a_ in ipairs(a) do
		if not find(a_,b) then table.insert(ret, a_) end
	end
	return ret
end

function symmetric(a, b)
	return difference(union(a,b), intersection(a,b))
end

function equal(a, b)
  return #difference(a,b)==0 and #difference(b,a)==0
end

getmetatable(sets).__newindex = function (table, key, val)
    error('attempt to write to undeclared variable "' .. key .. '": '.. debug.traceback())
end
