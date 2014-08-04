-- Openresty init phases are executed in following order:
-- init_by_lua*
-- init_worker_by_lua*

-- code evaluated in init_by_lua is shared to next phases, so loading this module in init_by_lua
-- will initialize same seed for all workers and it will happen just once because of code caching

-- also don't be afraid that this is executed on every call when lua code cache is off
-- because init_by_lua is evaluated for every call

local randomseed = {}

randomseed.seed = function()
  ngx.log(ngx.DEBUG, 'running randomseed ', ngx.get_phase())
  math.randomseed(ngx.now())
  math.seeded = true

  -- First calls to math.random after a randomseed tend to be similar; discard them
  for i=1,3 do math.random() end
end

return randomseed

