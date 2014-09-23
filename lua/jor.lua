local jor = {}
local _VERSION = "0.0.1"
local _NAMESPACE = "jor"
local _URI = "/___jor"

local luajson = require "json"
local inspect = require "inspect"
local cache   = require 'cachejor'
local ngxjor  = require 'ngxjor'
local statsd  = require 'statsd_wrapper'

if os.getenv('SLUG_DISABLE_CACHE') then
  jor.driver = ngxjor
else
  jor.driver = cache:new(ngxjor)
end

local add_jor_timed_method = function(name, f)
  jor[name] = function(...)
    return statsd.timer('jor.' .. name, f, ...)
  end
end

add_jor_timed_method('last_id', function(self, collection)
  return tonumber(jor.driver:last_id(collection))
end)

add_jor_timed_method('count', function(self, collection, conditions)
  return jor.driver:count(collection, conditions, options)
end)

add_jor_timed_method('collections',function(self)
   return jor.driver:collections()
end)

add_jor_timed_method('is_auto_inc',function(self, collection)
											 return jor.driver:is_auto_increment(collection)
end)

add_jor_timed_method('set_auto_inc',function(self, collection, value)
											 return jor.driver:set_auto_increment(collection, value)
end)


add_jor_timed_method('exist', function(self, collection, conditions)
  local count, err = jor:count(collection, conditions)
  if not count then return nil, err end
  return count > 0
end)

add_jor_timed_method('create_collection', function(self, name, auto_incr)
  return jor.driver:create_collection(name, auto_incr)
end)

add_jor_timed_method('delete_collection', function(self, name)
  return jor.driver:delete_collection(name)
end)

add_jor_timed_method('reset', function(self)
  return jor.driver:reset()
end)

add_jor_timed_method('insert', function(self, collection, doc, options)
  ngx.log(ngx.INFO, "jor.insert: " .. collection .. " | " .. luajson.encode(doc) .. " | " .. luajson.encode(options))
  return jor.driver:insert(collection, doc, options)
end)

add_jor_timed_method('find', function(self, collection, doc, options)
  ngx.log(ngx.INFO, "jor.find: " .. collection .. " | " .. luajson.encode(doc) .. " | " .. luajson.encode(options))

  local results =  jor.driver:find(collection, doc, options or {})

  if type(results) == 'function' then return results end

  if not results or #results == 1 and results[1] == 'null' or results[1] == 'none'  then
    return {}
  end

  return results
end)

add_jor_timed_method('find_ids', function(self, collection, doc, options)
  return jor.driver:find_ids(collection, doc, options or {})
end)

add_jor_timed_method('find_first', function(self, collection, doc, options)
  options = options or {}
  options.max_documents = 1

  local arr, err = jor:find(collection, doc, options)

  if arr then
    return arr[1]
  else
    return nil, err
  end
end)

add_jor_timed_method('delete', function(self, collection, doc, options)
  ngx.log(ngx.INFO, "jor.delete: " .. collection .. " | " .. luajson.encode(doc))
  return jor.driver:delete(collection, doc, options)
end)

add_jor_timed_method('update', function(self, collection, doc, doc_attrs, options)
  ngx.log(ngx.INFO, "jor.update: " .. collection .. " | " .. luajson.encode(doc) .. " | " .. luajson.encode(doc_attrs) .. " | " .. luajson.encode(options))
  return jor.driver:update(collection, doc, doc_attrs, options or {})
end)

add_jor_timed_method('delete_collection', function(self, collection)
  return jor.driver:delete_collection(collection)
end)

add_jor_timed_method('lock', function(self, key)
  return jor.driver:lock(key)
end)


add_jor_timed_method('unlock', function(self, key)
  return jor.driver:unlock(key)
end)

return jor
