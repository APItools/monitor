local PATH = (...):match("(.+%.)[^%.]+$") or ""

local Parameter   = require(PATH .. 'parameter')
local array       = require(PATH .. 'lib.array')
local straux      = require(PATH .. 'lib.straux')
local md5         = require(PATH .. 'lib.md5')

local WILDCARD = straux.WILDCARD

local Operation = {}
local Operationmt = {__index = Operation}

local VERBS = {
  GET     = "Get",
  POST    = "Create",
  PUT     = "Modify",
  DELETE  = "Delete",
  HEAD    = "Head",
  PATCH   = "Patch"
}

local function get_verb_for_method(method, number)
  if number == 0 and method == "GET" then return "List" end
  return VERBS[method] or straux.titleize(method)
end

local function initialize_guid(self)
  self.guid = self.guid or md5.sumhexa(self.api.host.base_path .. self.api.path .. self.method)
end


local function get_tokens_without_EOL_or_extension(self)
  local result = array.copy(self.api.tokens)
  local length = #result

  result[length] = nil -- remove EOL
  length = length - 1

  local extension = result[length]
  if extension and straux.begins_with(extension, '.') then
    result[length] = nil
  end
  return result
end

function Operation:new(api, method, guid)
  return setmetatable({
    api        = api,
    method     = method,
    parameters = {},
    guid       = guid
  }, Operationmt)
end

function Operation:parse_path_parameters(path)
  local tokens = straux.tokenize(path)

  local result = {}

  for i=1, #self.api.tokens do
    local my_token = self.api.tokens[i]
    if my_token == WILDCARD then
      local param_name   = straux.make_id(i > 1 and tokens[i-1] or "param")
      result[param_name] = tokens[i]
    end
  end

  return result
end

function Operation:parse_body_parameters(body, headers)
  if type(headers) == 'table' and headers['Content-Type'] == "application/x-www-form-urlencoded" then
    if type(body) == 'table' then return 'body',  body end
    return 'body', {__body = body}
  else
    return 'query', {__body = body}
  end
end

function Operation:parse_query_parameters(query)
  if type(query) == 'table' then return query end
  return straux.parse_query(query)
end

function Operation:add_parameter_info(path, query, body, headers)
  query    = query or ""
  body     = body or ""
  headers  = headers or {}

  self:add_parameters('header',  headers)
  self:add_parameters('path',  self:parse_path_parameters(path))
  self:add_parameters('query', self:parse_query_parameters(query))

  if self.method ~= 'GET' and self.method ~= 'HEAD' then
    local body_kind, body_parameters  = self:parse_body_parameters(body, headers)
    self:add_parameters(body_kind, body_parameters)
  end
end

function Operation:add_parameters(kind, parameters)
  for name, value in pairs(parameters) do
    self:add_parameter(kind, name, value)
  end
end

function Operation:add_parameter(kind, name, value)
  self.parameters[name] = self.parameters[name] or Parameter:new(self, kind, name)
  local p = self.parameters[name]

  p.kind = kind
  p:add_value(value)
end

function Operation:get_parameter_names()
  local names = {}
  for name,_ in pairs(self.parameters) do
    names[#names + 1] = name
  end
  return array.sort(names)
end

function Operation:get_nickname()
  return table.concat(straux.split(self:get_summary(), ' '), '_'):lower()
end

function Operation:get_summary()

  local tokens = get_tokens_without_EOL_or_extension(self)
  local tokens_length = #tokens

  local wildcard_positions, wildcard_length = {}, 0
  for i=tokens_length,1,-1 do
    if tokens[i] == WILDCARD then
      wildcard_length = wildcard_length + 1
      wildcard_positions[wildcard_length] = i
    end
  end

  local last_wildcard_pos = wildcard_positions[1]
  local last_name         = last_wildcard_pos and last_wildcard_pos > 1 and tokens[last_wildcard_pos - 1]
  local last_suffix       = last_wildcard_pos and tokens[last_wildcard_pos + 1]

  local verb = get_verb_for_method(self.method, wildcard_length)
  local words = {}

  if wildcard_length == 0 then

    local last_token = tokens[tokens_length]
    words = last_token and { verb, last_token } or {verb}

  elseif wildcard_length == 1 then

    if self.method == 'PUT' and last_name and last_suffix then
      words = { straux.titleize(last_suffix), last_name, 'by id'}
    elseif self.method == 'POST' then
      if last_name and last_suffix then
        words = { verb, last_suffix, 'of', last_name }
      elseif last_name then
        words = { verb, last_name, 'by id' }
      elseif last_suffix then
        words = { verb, last_suffix }
      end
    else
      if last_name then
        words = { verb, last_name, 'by id'}
      else
        words = { verb, 'by id'}
      end
    end

  else -- wildcard_length > 1

    local previous_wildcard_pos = wildcard_positions[2]
    local previous_name = previous_wildcard_pos and previous_wildcard_pos > 1 and tokens[previous_wildcard_pos - 1]

    if previous_name then
      words = {verb, last_name, 'of', previous_name }
    else
      words = {verb, last_name}
    end

  end

  return table.concat(words, ' ')
end

function Operation:to_swagger()
  local parameters = {}
  for _,name in ipairs(self:get_parameter_names()) do
    parameters[#parameters + 1] = self.parameters[name]:to_swagger()
  end

  initialize_guid(self)

  return {
    httpMethod  = self.method, -- old swagger spec
    method      = self.method, -- new swagger spec
    nickname    = self:get_nickname(),
    summary     = self:get_summary(),
    notes       = 'Automatically generated Operation spec',
    guid        = self.guid,
    parameters  = parameters
  }
end

function Operation:to_table()
  local parameter_tables, len = {},0
  for _,name in ipairs(self:get_parameter_names()) do
    len = len + 1
    parameter_tables[len] = self.parameters[name]:to_table()
  end

  initialize_guid(self)

  return {
    method     = self.method,
    guid       = self.guid,
    parameters = parameter_tables
  }
end

function Operation:new_from_table(api, tbl)
  if type(tbl) ~= 'table' or type(tbl.method) ~= 'string' then
    error('tbl required with a method')
  end

  local operation = Operation:new(api, tbl.method, tbl.guid)

  if type(tbl.parameters) == 'table' then
    for _,param_tbl in ipairs(tbl.parameters) do
      local parameter = Parameter:new_from_table(self, param_tbl)
      operation.parameters[parameter.name] = parameter
    end
  end

  return operation
end

return Operation
