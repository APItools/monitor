local PATH = (...):match("(.+%.)[^%.]+$") or ""

local Host   = require(PATH .. 'host')
local array  = require(PATH .. 'lib.array')

local Brain = {}
local Brainmt = {__index = Brain}



function Brain:new(threshold, unmergeable_tokens)
  return setmetatable({
    threshold          = threshold          or 1.0,
    unmergeable_tokens = unmergeable_tokens or {},
    hosts              = {}
  }, Brainmt)
end

function Brain:get_hostnames()
  local names = {}
  for name,_ in pairs(self.hosts) do names[#names + 1] = name end
  return array.sort(names)
end

function Brain:learn(method, hostname, base_path, path, query, body, headers)
  return self:get_or_create_host(hostname, base_path):learn(method, path, query, body, headers)
end

function Brain:get_swagger(hostname)
  return self:get_or_create_host(hostname):to_swagger()
end

function Brain:get_or_create_host(hostname, base_path)
  self.hosts[hostname] = self.hosts[hostname] or
    Host:new(hostname, base_path, self.threshold, self.unmergeable_tokens)
  return self.hosts[hostname]
end

return Brain
