local jor     = require 'jor'
local inspect = require 'inspect'

local model_helpers = {}

local isEmpty = function(tbl)
  return next(tbl) == nil
end

local process_conditions = function(conditions)
  if not conditions then error('No conditions where specified') end
  if type(conditions) ~= "table" then
    conditions = { _id = tonumber(conditions) }
  end
  return conditions
end

local process_conditions_not_empty = function(conditions)
  conditions = process_conditions(conditions)
  if isEmpty(conditions) then error('conditions can not be an empty table') end
  return conditions
end

------

local check_collection = function(collection)
  if type(collection) ~= 'string' then
    error("A collection name was needed, but received " .. tostring(collection))
  end
end

model_helpers.delete_collection = function(name)
   return jor:delete_collection(name)
end

model_helpers.create = function(collection, values, options)
  check_collection(collection)
  return jor:insert(collection, values, options)[1]
end

model_helpers.all = function(collection, conditions, options)
  check_collection(collection)
  conditions = process_conditions(conditions or {})
  options = options or {}

  local result, err = jor:find(collection, conditions, options)

  if result then return result end
  return {}
end

model_helpers.find = function(collection, conditions, options)
  check_collection(collection)
  return jor:find_first(collection, process_conditions_not_empty(conditions), options)
end

model_helpers.find_or_error = function(collection, conditions, error_message)
  local elem, err = model_helpers.find(collection, conditions)
  if elem then return elem end
  error_message = error_message or "could not find element in collection " .. tostring(collection) .. '. Error: ' .. tostring(err)
  error({status = ngx.HTTP_NOT_FOUND, message = error_message})
end

model_helpers.get_last_id = function(collection)
  check_collection(collection)
  return jor:last_id(collection) or 0
end

model_helpers.delete = function(collection, conditions, options)
  check_collection(collection)
  return jor:delete(collection, process_conditions(conditions), options)
end

model_helpers.delete_or_error = function(collection, conditions, error_message)
  check_collection(collection)
  local count = model_helpers.count(collection, conditions)
  if count == 0 then
    error_message = error_message or "could not find element in collection " .. tostring(collection) .. '. Error: ' .. tostring(err)
    error({status = ngx.HTTP_NOT_FOUND, message = error_message})
  end
  return model_helpers.delete(collection, conditions)
end

model_helpers.update_or_error = function(collection, conditions, values, error_message, options)
  check_collection(collection)
  conditions = process_conditions(conditions)
  model_helpers.find_or_error(collection, conditions, error_message)
  local updated_model, err = jor:update(collection, conditions, values, options)
  if updated_model then return updated_model[1] end
  error(err)
end

model_helpers.update = function(collection, conditions, values, options)
  check_collection(collection)
  conditions = process_conditions(conditions)

  local updated_model, err = jor:update(collection, conditions, values, options)
  if updated_model then return updated_model[1] end
  error(err)
end

model_helpers.update_with_versioning = function(collection, conditions, values)
  check_collection(collection)
  conditions = process_conditions(conditions)

  local current_object = model_helpers.find(collection, conditions)
  if current_object then
    model_helpers.create("versions", {collection = collection, object = current_object})
  end

  return model_helpers.update(collection, conditions, values)
end

model_helpers.count = function(collection, conditions, options)
  check_collection(collection)
  conditions = process_conditions(conditions or {})
  return jor:count(collection, conditions, options)
end

model_helpers.save = function(collection, values, options)
  local id = values._id
  if id and model_helpers.find(collection, id) then
    return model_helpers.update(collection, id, values, options)
  else
    return model_helpers.create(collection, values, options)
  end
end

return model_helpers
