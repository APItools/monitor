--[[

  Do not refactor function names, this is a port to http://github.com/solso/jor where all
  new features are and then they get ported to the nginx+lua version

]]--
local redis    = require "concurredis"
local luajson  = require "json"
local sets     = require "sets"
local inspect  = require "inspect"
local fun      = require 'functional'

local ngxjor = {}
local _VERSION = "0.0.1"
local _NAMESPACE = "jor"

local _ROOT = '!'
local DEFAULT_OPTIONS = {
  max_documents = 1000,
  raw = false,
  only_ids = false,
  reversed = false,
  excluded_fields_to_index = {}
}

local _SELECTORS = {
  compare = {"$gt", "$gte", "$lt", "$lte"},
  sets = {"$in", "$all"}
}

local _SELECTORS_ALL = {}
for k, v in pairs(_SELECTORS) do
  for i, v2 in ipairs(v) do
    _SELECTORS_ALL[v2] = true
  end
end

local _ERRORS = {
  TypeNotSupported = "The type is not supported",
  InvalidFieldName = "Invalid field name",
  IncompatibleSelectors = "Selectors cannot be mixed",
  CollectionAlreadyExists = "Collection already exists",
  CollectionDoesNotExist = "Collection does not exist"
}

local mt = { __index = ngxjor }

--
-- AUX FUNCTIONS
--

local function reverse_sort(a,b) return a > b end

local function truncate(t, len)
  if #t < len or len < 0 then return t end
  local res = {}
  for i=1, len do res[i] = t[i] end
  return res
end

local map = fun.map

local function shallow_clone(t1)
  local res = {}
  for i,v in pairs(t1) do
    res[i] = v
  end
  return res
end

local function deep_clone(t1)
  local res = {}
  for i,v in pairs(t1) do
    if type(v) == 'table'  then
      res[i] = deep_clone(v)
    else
      res[i] = v
    end
  end
  return res
end

local function shallow_merge(default, dominant)  -- returns new table with contents of both tables
  local res = shallow_clone(default)
  for k,v in pairs(dominant) do
    res[k] = v
  end
  return res
end

local function deep_merge(t1, t2)
  local res = deep_clone(t1)
  for k,v in pairs(t2) do
    if type(v) == 'table' and type(t1[k]) == 'table' then
      res[k] = deep_merge(v, t2[k])
    else
      res[k] = v
    end
  end
  return res
end

local function array_starts_with(original, match)
  if #match > #original then return false end

  for i=1, #match do
    if original[i] ~= match[i] then
      return false
    end
  end

  return true
end

local function substract_set(original, set_to_substract)
  for _,item in ipairs(set_to_substract) do
    if item.path_to[#item.path_to] == "_id"  then
      return nil, "_id is not an indexable field"
    end
  end

  local to_keep = {}
  for _,item in ipairs(original) do
    local found = false
    for _,to_exclude in ipairs(set_to_substract) do
      if not found and array_starts_with(item.path_to, to_exclude.path_to) then
        found = true
      end
    end
    if not found then
      table.insert(to_keep, item)
    end
  end
  return to_keep
end

local function is_empty(t) return next(t) == nil end

local function escape_slash(key)
  return tostring(key):gsub("/", "//")
end

local function to_table(...)
  if type(...) == 'table' then return ... end
  return {...}
end

local function build_key(...)
  return table.concat(map(escape_slash, to_table(...)), '/')
end

local function array_concat(a, b)
  local copy = shallow_clone(a)
  local a_len = #a
  for i=1,#b do copy[a_len + i] = b[i] end
  return copy
end

if _TEST then
   ngxjor.substract_set = substract_set
end

-- What happens if the name of the path in the index is String, but it's a number
-- { String = }
-- FIXME: security check
local function get_path_to_from_index(index)
  local ini_pos = index:find('/!') + 1
  local end_pos = index:find('/String') or
    index:find('/Numeric') or
    index:find('/TrueClass') or
    index:find('/FalseClass')
  return index:sub(ini_pos, end_pos-1)
end

local function _check_collection(collection)
  if type(collection) ~= 'string' then
    return false, 'Collection must be a string'
  end
  return true
end


local function _remove_index(collection, index, id)
  local type_of_index = index:sub(-5)
  local real_index = index:sub(1, -6)
  redis.execute(function(red)
    if type_of_index == '_zrem'  then
      red:zrem(real_index, id)
    elseif type_of_index == '_srem'  then
      red:srem(real_index, id)
    else
      error('unknown index type')
    end
  end)
end

local function _idx_key(collection, path_to, kind, obj)
  -- make an array from the rest of params as unpack has to be the last
  return build_key(_NAMESPACE , collection , "idx" , unpack(array_concat(path_to, {kind, obj})))
end

local function _idx_set_key(collection, id)
  return build_key(_NAMESPACE, collection , "sidx" , id)
end

local function _doc_set_key(collection)
  return build_key(_NAMESPACE, collection, "ssdocs")
end

local _doc_sset_key = _doc_set_key

local function _doc_key(collection, id)
  return build_key(_NAMESPACE, collection, "docs", id)
end

local function is_array(t)
  local i = 0
  for _ in pairs(t) do
    i = i + 1
    if t[i] == nil then return false end
  end
  return true
end

local function _table_keys(t)
  local res = {}
  for k, v in pairs(t) do
    table.insert(res,k)
  end
  return res
end

local function _table_values(t)
  local res = {}
  for k, v in pairs(t) do
    table.insert(res,v)
  end
  return res
end

-- this one could be replaced by a proper use of next()
local function _table_first(t)
  local res = {}
  for k, v in pairs(t) do
    return k, v
  end
  return nil
end

local function jor_type_of(x)
  if type(x) == 'string'  then
    return 'String'
  elseif type(x) == 'boolean'  then
    if x == true then
      return 'TrueClass'
    else
      return 'FalseClass'
    end
  elseif type(x) == 'number'  then
    return 'Numeric'
  elseif type(x) == 'userdata' then
    return 'userdata'
  else
    error('undefined type: ' .. tostring(x) .. '-- ' .. type(x))
  end
end


local function _add_index(collection, path, id)
  local obj_type = type(path.obj)
  local jor_type = jor_type_of(path.obj)
  local key = _idx_key(collection, path.path_to, jor_type, path.obj)
  return redis.execute(function(red)
    if obj_type == "string" then
      red:sadd(key, id)
      red:sadd(_idx_set_key(collection, id), key.."_srem") -- reverse index
    elseif  obj_type == "boolean" then
      red:sadd(key, id)
      red:sadd(_idx_set_key(collection, id), key.."_srem") -- reverse index
    elseif obj_type == "number" then
      red:sadd(key, id)
      red:sadd(_idx_set_key(collection, id), key.."_srem") -- reverse index
      key = _idx_key(collection, path.path_to, "Numeric")
      red:zadd(key, path.obj, id)
      red:sadd(_idx_set_key(collection, id), key.."_zrem") -- reverse index
    else
      return nil, _ERRORS["TypeNotSupported"]
    end
    return true
  end)
end

local function delete_reverse_indices(red, res, collection, id)

  red:init_pipeline()
  for i, index in ipairs(res) do
    local index_name, ends_with = index:match("^(.*)_([zs]rem)$")
    if ends_with == "zrem"  then
      red:zrem(index_name, id)
    elseif ends_with == "srem" then
      red:srem(index_name ,id)
    else
      error("delete by id with wrong type of column")
      -- this should not happen
    end
  end

  red:del(_idx_set_key(collection, id))
  red:zrem(_doc_set_key(collection),id)
  red:del(_doc_key(collection,id))

  local res, err = red:commit_pipeline()
  if res==nil then return nil, err end
  return true
end

local function _delete_by_id(collection, id)
  local res, err = _check_collection(collection)
  if not res then return nil, err end

  return redis.execute(function(red)
    local res, err = red:smembers(_idx_set_key(collection, id))
    if (res==nil) then return nil, err end

    delete_reverse_indices(red, res, collection, id)
  end)
end

local function _remove_missing_document(collection, id)
  ngx.log(ngx.WARN, 'removing document ' .. id .. ' from ' .. collection .. ' because it has no content')
  _delete_by_id(collection, id)
end

local function _load_documents(collection, ids)
  return redis.execute(function(red)

    red:init_pipeline()
    for _, id in ipairs(ids) do
      red:get(_doc_key(collection, tonumber(id)))
    end
    local res, err = red:commit_pipeline()
    if not res then return nil, err end

    local docs = {}

    for i=1, #res do
      -- ngx.null is equivalent to null and can't be decoded to json
      if ngx.null == res[i] then
        table.insert(docs, nil)
        _remove_missing_document(collection, ids[i])
      else
        table.insert(docs, luajson.decode(res[i]))
      end
    end

    return docs
  end)
end

local function _documents_iterator(collection, ids)
  local i = 0
  local n = table.getn(ids)
  return function ()
    return redis.execute(function(red)
      i = i + 1
      if i <= n then
        local id = ids[i]
        local res = red:get(_doc_key(collection, tonumber(id)))

        if res == ngx.null then
          return 'null'
        else
          return res
        end
      end
    end)
  end
end

function ngxjor.get_doc_paths(self, path, doc)
  if type(path) == 'string' then
    if path == '' then
      path = { }
    else
      path = { path }
    end
  end

  if type(doc)=="table" then
    local paths = {}

    if is_array(doc) then

      for _, v in ipairs(doc) do
        paths = array_concat(paths, self:get_doc_paths(path, v))
      end

    else

      for k, v in pairs(doc) do
        if _SELECTORS_ALL[k] then
          return {{path_to = path, obj = doc, class = "Hash", selector = true}}
        else
          paths = array_concat(paths, self:get_doc_paths(array_concat(path, {k}), v))
        end
      end

    end
    --print(inspect(paths))

    return paths
  else
    return {{path_to = path, obj = doc, class = jor_type_of(doc)}}
  end
end

function TraceOut(...)
   local args = {...}
   local str = ""
   -- ngx.log(0, inspect(args))
   for _,arg in pairs(args) do
      if type(arg) == "function" then
         str = str .. inspect(arg)
      else
         str = str .. arg
      end

   end
   ngx.log(0, str)
end

function DebugFunction (f)
  assert (type (f) == "string" and type (_G [f]) == "function",
          "DebugFunction must be called with a function name")
  local old_f = _G [f]  -- save original one for later
  _G [f] = function (...)  -- make new function
    local t = debug.getinfo (2, "ln")  -- get line and caller name
    t.name = t.name or "<unknown place>"
    TraceOut ("Function ", f, " called.")  -- show name
    TraceOut ("Called from ", t.name, " at line ", t.currentline)  -- show caller
    local n = select ("#", ...)  -- number of arguments
    if n == 0 then
      TraceOut ("No arguments.")
    else
      for i = 1, n do  -- show each argument
        TraceOut ("Argument ", i, " = ", tostring ((select (i, ...))))
      end -- for each argument
    end -- have some arguments
    old_f (...)  -- call original function now
  end -- debug version of the function
end -- DebugFunction


-- DebugFunction("get_doc_paths")

local function _next_id(collection)

  local res, err = _check_collection(collection)
  if not res then return nil, err end

  return redis.execute(function(red)
    local res, err = red:incrby(_NAMESPACE.."/"..collection.."/next_id",1)
    if (res==nil) then
      return nil, err
    else
      return res
    end
  end)
end


-- returns the key of _SELECTORS where selectors belong.
local function _check_selectors(selectors)
  for k, v in pairs(_SELECTORS) do
    local i = sets.intersection(selectors,v)
    if #v>0 and #selectors>0 and #selectors==#i then
      return k
    end
  end

  return nil, _ERRORS["IncompatibleSelectors"]

end

local function _fetch_ids_by_index(collection, path)

  local res, err = redis.execute(function(red)

    if path["selector"] then

      local selector_type, err = _check_selectors(_table_keys(path["obj"]))

      if selector_type == nil then return nil, err end

      if selector_type == "compare" then

        local k, v = _table_first(path.obj)

        local key = _idx_key(collection,path.path_to, jor_type_of(v))
        --local key = _idx_key(collection,path["path_to"],'Numeric')

        local rmin = "-inf"
        if path["obj"]["$gte"]~=nil then
          rmin = path["obj"]["$gte"]
        end
        if path["obj"]["$gt"] then
          rmin = "("..path["obj"]["$gt"]
        end

        local rmax = "+inf"
        if path["obj"]["$lte"]~=nil then
          rmax = path["obj"]["$lte"]
        end
        if path["obj"]["$lt"] then
          rmax = "("..path["obj"]["$lt"]
        end

        return red:zrangebyscore(key, rmin, rmax)

      elseif selector_type == "sets" then

        if path["obj"]["$in"] then
          local target = path["obj"]["$in"]
          local join_set = {}
          for i, v in ipairs(target) do
            local res, err = red:smembers(_idx_key(collection, path.path_to, jor_type_of(v),v))
            if not res then return nil, err end
            join_set = sets.union(join_set,res)
          end
          table.sort(join_set)
          return join_set

        elseif path["obj"]["$all"] then
          local target = path["obj"]["$all"]
          local join_set = {}
          for i, v in ipairs(target) do
            local res, err = red:smembers(_idx_key(collection, path.path_to,type(v),v))
            if not res then return nil, err end

            if i==1 then
              join_set = res
            else
              join_set = sets.intersection(join_set, res)
            end

            if #join_set==0 then
              return {}
            end
          end
          return join_set
        else
          -- more selectors of type "sets"
        end
      else
        -- more selectors types
      end

    else
      -- not a selector but value

      local res, err = red:smembers(_idx_key(collection, path.path_to, jor_type_of(path.obj), path["obj"]))
      if not res then return nil, _ERRORS["TypeNotSupported"] end
      return res
    end
  end)

  if res then res = map(tonumber, res) end

  return res, err
end

--
-- PUBLIC FUNCTIONS
--

function ngxjor.collections(self)
  return redis.execute(function(red)
    local collections = {}
    local res, err = red:smembers(_NAMESPACE .. "/collections")
    if not res then return nil, err end

    return res
  end)
end

function ngxjor.is_auto_increment(self, collection)
  return redis.execute(
    function (red)
      local autoinc_key = string.format("%s/collection/%s/auto-increment", _NAMESPACE, collection)
      return red:get(autoinc_key)
    end)
end

function ngxjor.set_auto_increment(self, collection, value)
  return redis.execute(
    function (red)
      local autoinc_key = string.format("%s/collection/%s/auto-increment", _NAMESPACE, collection)
      return red:set(autoinc_key, value)
    end)
end


function ngxjor.last_id(self, collection)
  return redis.execute(function(red)
    local res, err = red:get(_NAMESPACE.."/"..collection.."/next_id")
    if (res==nil) then
      return nil, err
    else
      return res
    end
  end)
end

local function ensure_list(l)
  if is_array(l) then
    return l
  else
    return {l}
  end
end

local function use_or_generate_id(collection, doc)
  return redis.execute(function(red)
    local autoinc = red:get(_NAMESPACE .. "/collection/" .. collection .. "/auto-increment") ~= 'false'

    if autoinc and doc._id then
      error("collection ".. collection .." is autoincremental, you can't provide _id = " .. inspect(doc))
    elseif autoinc and not doc._id then
      local _id, err = _next_id(collection)
      if not _id then
        return nil, err
      else
        return _id
      end
    elseif not autoinc and doc._id then
      if type(doc._id) ~= 'number' or doc._id < 0 then error('wrong id') end
      return doc._id
    elseif not autoinc and not doc._id then
      error("collection " .. collection .. " is not autoincremental. you must provide an _id")
    end
  end)
end


function ngxjor.insert(self, collection, docs, options)
  local res, err = _check_collection(collection)
  if not res then return nil, err end

  options = options or {}

  return redis.execute(function(red)
    local err
    local list_docs = ensure_list(docs)

    local function insert_document(doc)
      local id = use_or_generate_id(collection, doc)

      doc = deep_clone(doc) -- do not mutate passed document
      doc._id = id

      doc._created_at = doc._created_at or ngx.now()
      doc._updated_at = doc._updated_at or ngx.now()

      local encd = luajson.encode(doc)
      local paths = assert(self.get_doc_paths(self, _ROOT , doc))

      if options.excluded_fields_to_index  then
        local excluded_paths = self.get_doc_paths(self, _ROOT, options.excluded_fields_to_index)
        paths = substract_set(paths, excluded_paths)
      end

      red:watch(_doc_key(id))
      local exists = red:get(_doc_key(id))
      if exists then
        red:multi()
        red:exec()
      else

      end


      local ok, err = red:multi()
      if not ok then
        return nil, err
      end

      red:set(_doc_key(collection,id),encd)
      red:zadd(_doc_set_key(collection),id, id)

      -- TODO: excluded_fields_to_index
      -- TODO: redis watch
      for _i, path in ipairs(paths) do
        _add_index(collection, path, id)
      end

      local ok, err = red:exec()
      if not ok then
        return nil, err
      else
        -- will have to check that all the responses are OK, none starting with ERR
        -- exec ans: ["OK",[false,"ERR Operation against a key holding the wrong kind of value"]]
        return doc
      end
    end

    return map(insert_document, list_docs)
  end)
end

function ngxjor.delete(self, collection, doc, options)

  options = shallow_merge(DEFAULT_OPTIONS, options or {})
  options.only_ids = true

  local res, err = _check_collection(collection)
  if not res then return nil, err end

  local ids, err = ngxjor.find_with_options(self, collection, doc, options)

  if not ids or #ids == 0 then
    return nil, err
  else
    for _, id in ipairs(ids) do
      _delete_by_id(collection, id)
    end
    return #ids
  end
end

function ngxjor.find(self, collection, doc, options)
  return ngxjor.find_with_options(self, collection, doc, options or {})
end

function ngxjor.find_with_options(self, collection, doc, options)
  local res, err = _check_collection(collection)
  if not res then return nil, err end

  local num_docs = options.max_documents or 999

  local ids, err = redis.execute(function(red)
    if is_empty(doc) then
      if options.reversed then
        return red:zrevrange(_doc_sset_key(collection), 0 , num_docs)
      else
        return red:zrange(_doc_sset_key(collection), 0 , num_docs)
      end
    end

    local ids = {}

    local paths = self.get_doc_paths(self, _ROOT , doc)

    -- inject 'pattern'. Get docs that match all the constraints
    for i, path in ipairs(paths) do
      local tmp_res, err = _fetch_ids_by_index(collection, path)

      if not tmp_res then
        return nil, err
      end

      if i == 1 then
        ids = tmp_res
      else
        ids = sets.intersection(ids,tmp_res)
      end
    end

    return ids
  end)

  if not ids then return nil, err end

  ids = map(tonumber, ids)

  if options.reversed then
    table.sort(ids, reverse_sort)
  else
    table.sort(ids)
  end

  ids = truncate(ids, num_docs)

  -- we have now the list of id's the match the criteria, we can
  -- fetch the docs by id now. Pagination (cursor) should go here.
  if options.only_ids then
    return ids
  end


  if options.iterator then
    return _documents_iterator(collection, ids)
  else
    return _load_documents(collection, ids)
  end
end

-- Used only in tests
function ngxjor.count(self, collection, doc)
  doc = doc or {}

  local res, err = _check_collection(collection)
  if not res then return nil, err end

  local ids, err = ngxjor:find(collection, doc, {only_ids = true, max_documents = -1})
  if not ids then return nil, err end

  return #ids
end

function ngxjor.create_collection(self, name, auto_increment)
  if not ngx.re.match(name,"^[a-zA-Z0-9_-]+$") then return nil, "Invalid collection name: " .. name end
  return redis.execute(function(red)
    local res, err = red:sadd(_NAMESPACE.."/collections", name)
    if res == nil then
      return nil, err

    elseif res == 1 then
      res, err = red:set(_NAMESPACE .. "/collection/" .. name .. "/auto-increment", tostring(auto_increment or false) )

      if res then return true
      else return false, "couldn't set autoincrement"
      end
    elseif res == 0 then
      return true
    else
      return false, "some strange thing happened"
    end
  end)
end

function ngxjor.delete_collection(self, collection)

  local res, err = _check_collection(collection)
  if not res then return nil, err end

  return redis.execute(function(red)
    local a = red:del(_NAMESPACE .. "/collection/" .. collection .. "/auto-increment")
    local res, err = red:srem(_NAMESPACE.."/collections", collection)
    if not res then
      return nil, err
    else
      if res==1 then
        local res, err = ngxjor.delete(self, collection, {})
        if res==nil then
          return nil, err
        end
        return res
      else
        return nil, _ERRORS["CollectionDoesNotExist"]
      end
    end
  end)
end


function ngxjor.update(self, collection, doc, doc_attrs, options)
  local res, err = _check_collection(collection)
  if not res then return nil, err end

  options = shallow_merge(DEFAULT_OPTIONS, options or {})
  doc_attrs = shallow_clone(doc_attrs)
  doc_attrs._updated_at = ngx.now()
  doc_attrs._id = nil

  local paths_all = self.get_doc_paths(self, _ROOT, doc_attrs)
  local excluded_paths = {}
  local paths_to_index = paths_all

  if options.excluded_fields_to_index then
    excluded_paths = self.get_doc_paths(self, _ROOT, options.excluded_fields_to_index)
    paths_to_index = substract_set(paths_to_index, excluded_paths)
  end

  local matches, err = ngxjor:find_with_options(collection, doc, options)
  if not matches then return nil, err end

  local to_remove = {}
  local results = {}

  return redis.execute(function(red)
    for _,document in ipairs(matches) do

      local indexes, err = red:smembers(_idx_set_key(collection, document._id))
      if not indexes then return nil, err end

      for _,index in ipairs(indexes) do
        local path_to_from_index = get_path_to_from_index(index)

        for _,path in ipairs(paths_all) do
          local key = build_key(path.path_to)

          if not path.obj then
            if key == path_to_from_index then
              table.insert(to_remove, index)
            elseif path_to_from_index:find(key .. '/') then
              table.insert(to_remove, index)
            end
          else
            if key == path_to_from_index  then
              table.insert(to_remove, index)
            end
          end
        end
      end

      red:init_pipeline()
      for _,index_to_rm in ipairs(to_remove) do
        _remove_index(collection, index_to_rm, document._id)
        red:srem(_idx_set_key(collection, document._id), index_to_rm)
      end
      local res, err = red:commit_pipeline()
      if not res then
        return nil , err
      end

      local new_doc = deep_merge(document, doc_attrs)
      local encd = luajson.encode(new_doc)

      local res = red:multi()
      red:set(_doc_key(collection, new_doc._id), encd)
      for _,path in ipairs(  paths_to_index) do
        _add_index(collection, path, new_doc._id)
      end
      local res = red:exec()
      table.insert(results, new_doc)
    end
    return results
  end)
end

function ngxjor.reset(self)
  local script = ([[
    for _,k in ipairs(redis.call('keys', '%s/*')) do
      redis.call('del', k)
    end
  ]]):format(_NAMESPACE)
  return redis.execute(function(red)
    return red:eval(script, 0)
  end)
end

function ngxjor.lock(self, key)
  local key = _NAMESPACE .. "/locks/" .. key
  return redis.execute(function(red)
    return red:incr(key)
  end)
end

function ngxjor.unlock(self, key)
  local key = _NAMESPACE .. "/locks/" .. key
  return redis.execute(function(red)
    return red:decr(key)
  end)
end

function ngxjor.delete_reverse_indices(self, collection, id)
  assert(id)

  redis.execute(function(red)
    red:del(_idx_set_key(collection, id))
  end)
end

-- removes the object generating the reverse indices on the fly and
-- removing them
function ngxjor.wipe_object(self, collection, id)
  local object = assert(self:find(collection, { _id = id }))
  local paths = assert(self.get_doc_paths(self, _ROOT, object))
  -- map paths to the result of _add_index(...)

  for _i, path in ipairs(paths) do
    _add_index(collection, path, id)
  end

  return ngxjor.delete(self, collection, { _id = id })
end

return ngxjor
