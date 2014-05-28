local PATH = (...):match("(.+%.)[^%.]+$") or ""

local array     = require(PATH .. 'lib.array')
local straux    = require(PATH .. 'lib.straux')
local md5       = require(PATH .. 'lib.md5')
local API       = require(PATH .. 'api')
local inspect = require 'inspect'

local EOL      = straux.EOL
local WILDCARD = straux.WILDCARD

local function merge(t, other)
  for k,v in pairs(other) do
    t[k] = t[k] or v
  end
  return t
end

local function get_max(t, default)
  local max = default or -math.huge
  for _,v in pairs(t) do
    if v > max then max = v end
  end
  return max
end

local function is_empty(t)
  return next(t) == nil
end

local function is_mergeable(self, token1, token2)

  if -- unmergeables
     array.includes(self.unmergeable_tokens, token1) or
     array.includes(self.unmergeable_tokens, token2) or
     -- formats
     straux.begins_with(token1, '.') or
     straux.begins_with(token2, '.') then
    return false
  end

  local score = self.score

  local score1 = score[token1] or 0
  local score2 = score[token2] or 0

  local max = get_max(score, 0)

  if max > 0 then
    score1 = score1 / max
    score2 = score2 / max
  else
    score1 = 0
    score2 = 0
  end

  return score1 <= self.threshold and
         score2 <= self.threshold
end

local function find_mergeable_sibling(self, node, current_token, next_token)
  if not next_token then return nil end
  for sibling, nephews in pairs(node) do
    for token,_ in pairs(nephews) do
      if token == next_token and is_mergeable(self, sibling, current_token) then
        return sibling
      end
    end
  end
end

local function get_path_score(self, path)
  local tokens = straux.tokenize(path)

  local score = self.score

  local result = 0
  for i=0, #tokens do
    result = result + (score[tokens[i]] or 0)
  end
  return result
end

local function refresh_apis(self)
  local valid_paths = self:get_paths()
  for api_path, _ in pairs(self.apis) do
    if not array.includes(valid_paths, api_path) then
      self.apis[api_path] = nil
    end
  end
  for _,path in ipairs(valid_paths) do
    self.apis[path] = self.apis[path] or API:new(self, path)
  end
end

local function insert_path(self, path)
  local score  = self.score
  local node   = self.root

  local tokens = straux.tokenize(path)

  for i=1, #tokens do
    local token = tokens[i]
    if token ~= EOL then
      score[token] = (score[token] or 0) + 1
    end

    if not node[token] then
      local sibling = find_mergeable_sibling(self, node, token, tokens[i+1])

      if sibling then
        if sibling ~= WILDCARD then
          node[WILDCARD] = node[WILDCARD] or {}
          merge(node[WILDCARD], node[sibling])
          node[sibling] = nil
        end
        token = WILDCARD
      else
        node[token] = {}
      end
    end

    node = node[token]
  end
end

local function increase_path_score(self, path)
  local score = self.score
  for _,token in ipairs(straux.tokenize(path)) do
    score[token] = (score[token] or 0) + 1
  end
end

local function add_path(self, path)
  local paths = self:match(path)
  local length = #paths

  if length == 0 then
    insert_path(self, path)
    refresh_apis(self)
    return path
  elseif length == 1 then
    increase_path_score(self, paths[1])
    return paths[1]
  else -- length > 1 => problem
    local min,max = math.huge, -math.huge
    local min_path, max_path
    for i=1,length do
      local score = get_path_score(self, paths[i])
      if score < min then
        min = score
        min_path = paths[i]
      end
      if score > max then
        max = score
        max_path = paths[i]
      end
    end

    increase_path_score(self, max_path)
    -- removes one path
    self:forget(min_path)
    refresh_apis(self)
    return max_path
  end
end


local function get_paths_recursive(self, node, prefix)
  local result = {}
  for token, children in pairs(node) do
    if token == EOL then
      result[#result + 1] = prefix
    else
      local separator = straux.begins_with(token, '.') and "" or "/"
      array.append(result, get_paths_recursive(self, children, prefix .. separator .. token))
    end
  end
  return result
end

local function initialize_guid(self)
  self.guid  = self.guid or md5.sumhexa(self.base_path)
end

----------------------------------------

local Host = {}
local Hostmt = {__index = Host}

function Host:new(hostname, base_path, threshold, unmergeable_tokens, guid)
  base_path = base_path or hostname
  return setmetatable({
    threshold           = threshold          or 1.0,
    unmergeable_tokens  = unmergeable_tokens or {},
    hostname            = hostname,
    base_path           = base_path,
    root                = {},
    score               = {},
    apis                = {},
    guid                = guid
  }, Hostmt)
end

function Host:match(path)
  return array.choose(self:get_paths(), function(x)
    return straux.is_path_equivalent(path, x)
  end)
end

function Host:find_api_by_equivalent_path(path)
  for api_path, api in pairs(self.apis) do
    if straux.is_path_equivalent(path, api_path) then return api end
  end
end

function Host:find_apis_by_subpath(subpath)
  local paths = array.choose(self:get_paths(), function(path)
    return string.find(path, subpath, 1, true)
  end)

  return array.map(paths, function(path) return self.apis[path] end)
end

function Host:get_paths()
  return array.sort(get_paths_recursive(self, self.root, ""))
end

function Host:learn(method, path, query, body)
  local api_path = add_path(self, path)

  local api = self:find_api_by_equivalent_path(path)

  if api then
    api:add_operation_info(method, path, query, body, headers)
  else
    local url = path
    if query then url = url .. "?" .. inspect(query) end
    ngx.log(ngx.WARN, "autoswagger could not learn " .. method .. " " .. url)
  end

  return api_path
end

function Host:forget(path)

  local tokens = straux.tokenize(path)
  local node   = self.root

  local nodes, length  = {}, 0

  for i=1,#tokens do
    length = length + 1
    nodes[length] = node
    node = node[tokens[i]] or node[WILDCARD]
    if not node then return false end
  end

  for i=length, 1, -1 do
    for token,children in pairs(nodes[i]) do
      if is_empty(children) then
        local buffer = {}
        for j=1, i do
          buffer[#buffer+1] = tokens[j]
        end
        nodes[i][token] = nil
      end
    end
  end

  return true
end

function Host:to_swagger()
  local swagger_apis = {}
  for _,api in pairs(self.apis) do
    swagger_apis[#swagger_apis + 1] = api:to_swagger()
  end

  initialize_guid(self)

  return {
    apiVersion     = "1.0",
    swaggerVersion = "1.2",
    hostname       = self.hostname,
    basePath       = self.base_path,
    models         = {},
    guid           = self.guid,
    apis           = swagger_apis
  }
end

function Host:to_table()
  local api_tables = {}
  for _,api in pairs(self.apis) do
    api_tables[#api_tables + 1] = api:to_table()
  end

  initialize_guid(self)

  return {
    hostname            = self.hostname,
    basePath            = self.base_path,
    threshold           = self.threshold,
    unmergeable_tokens  = self.unmergeable_tokens,
    guid                = self.guid,
    apis                = api_tables,
    root                = self.root
  }
end

function Host:new_from_table(tbl)
  if type(tbl) ~= 'table' or type(tbl.basePath) ~= 'string' then
    error('tbl and tbl.basePath must exist')
  end

  local hostname = tbl.hostname or tbl.basePath

  local host = Host:new(hostname, tbl.basePath, tbl.threshold, tbl.unmergeable_tokens, tbl.guid)

  if type(tbl.root) == 'table' then
    host.root = tbl.root
  end

  if type(tbl.apis) == 'table' then
    for _,api_tbl in ipairs(tbl.apis) do
      local api = API:new_from_table(host, api_tbl)
      host.apis[api.path] = api
    end
  end

  return host
end



return Host
