local PATH = (...):match("(.+%.)[^%.]+$") or ""

local straux     = require(PATH .. 'lib.straux')
local array      = require(PATH .. 'lib.array')
local md5        = ngx.md5 or require(PATH .. 'lib.md5').sumhexa
local Operation  = require(PATH .. 'operation')

local WILDCARD = straux.WILDCARD

local API = {}
local APImt = {__index = API}

local function  initialize_guid(self)
  self.guid = self.guid or md5(self.host.base_path .. self.path)
end

function API:new(host, path, guid)
  return setmetatable({
    host        = host,
    path        = path,
    tokens      = straux.tokenize(path),
    operations  = {},
    guid        = guid
  }, APImt)
end

function API:add_operation_info(method, path, query, body, headers)
  method   = string.upper(method)

  self.operations[method] = self.operations[method] or Operation:new(self, method)
self.operations[method]:add_parameter_info(path, query, body, headers)
end

function API:get_methods()
  local methods = {}
  for method,_ in pairs(self.operations) do
    methods[#methods + 1] = method
  end
  return array.sort(methods)
end

function API:get_swagger_path()
  local tokens = self.tokens
  local buffer = {}

  for i=1,#tokens do
    local token = tokens[i]
    if token == WILDCARD then
      local id = straux.make_id(i > 1 and tokens[i-1] or 'param')
      buffer[i] = '{'.. id .. '}'
    else
      buffer[i] = token
    end
  end

  return array.untokenize(buffer)
end

function API:to_swagger()
  local operations = {}
  for _,method in ipairs(self:get_methods()) do
    operations[#operations + 1] = self.operations[method]:to_swagger()
  end

  initialize_guid(self)

  return {
    path        = self:get_swagger_path(),
    guid        = self.guid,
    description = "Automatically generated API spec",
    operations  = operations
  }
end

function API:to_table()
  local operation_tables, len = {}, 0
  for _,method in ipairs(self:get_methods()) do
    len = len + 1
    operation_tables[len] = self.operations[method]:to_table()
  end

  initialize_guid(self)

  return {
    path        = self.path,
    guid        = self.guid,
    operations  = operation_tables
  }
end

function API:new_from_table(host, tbl)
  if type(tbl) ~= 'table' or type(tbl.path) ~= 'string' then
    error('the tbl parameter must be a table containig at least a path')
  end

  local api = API:new(host, tbl.path, tbl.guid)

  if type(tbl.operations) == 'table' then
    for _,operation_tbl in ipairs(tbl.operations) do
      local operation = Operation:new_from_table(api, operation_tbl)
      api.operations[operation.method] = operation
    end
  end

  return api
end

return API
