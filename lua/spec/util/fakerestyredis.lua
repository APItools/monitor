local redis = require 'redis' -- this uses lua-redis

local fakerestyredis = {}

local Res = {}
local Res_mt = {__index = Res}

-- handle all regular lua-redis methods by redirecting to lua-redis
for command,_ in pairs(redis.commands) do
  Res[command] = function(self, ...)
    return self.client[command](self.client, ...)
  end
end

-- handle exclusive resty-redis methods
function Res:init_pipeline()
  self.pipeline = {}
  self.get = function(self, ...)
    self.pipeline[#self.pipeline + 1] = {'get', ... }
  end
end

function Res:commit_pipeline()
  self.get = nil
  local results = {}
  for i,command in ipairs(self.pipeline) do
    local method = table.remove(command, 1)
    results[i] = self[method](self, unpack(command))
  end
  self.pipeline = nil
  return results
end

function Res:set_keepalive(a,b)
  self.client:quit()
  self.client = nil
end

function Res:connect(address, port)
  local client, err = redis.connect(address, port)
  if not client then return nil, err end
  self.client = client
  return self
end


function fakerestyredis:new()
  return setmetatable({}, Res_mt)
end

package.loaded['resty.redis'] = fakerestyredis

return fakerestyredis
