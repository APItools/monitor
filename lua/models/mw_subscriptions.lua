local http = require 'http'
local Event = require 'models.event'
local m = require 'model_helpers'
local luajson = require 'json'


-- id
-- user
-- repo
-- current_version
-- latest_seen_version

local collection = 'middleware_subscriptions'
local mw = {}

mw.get_updates = function(user, repo)
  local token = "access_token=60b6f9b60278b86a843d34f52558df7f016f0399"
  local headers = { Accept = 'application/vnd.github.raw' }
  local url = 'https://api.github.com/repos/' .. user .. '/' .. repo
  local info = http.simple{url = url .. "?" .. token, headers = headers}
  local spec = http.simple{url = url .. '/contents/brainslug.json' .. "?" .. token, headers = headers }
  local github = { spec = luajson.decode(spec), info = luajson.decode(info) }
  return github
end

mw.check_updates_for = function(subscription)
  local new_spec = mw.get_updates(subscription.user, subscription.repo)
  local new_version = Version:new(new_spec.version)
  local current_version = Version:new(subscription.version)
  if new_version > current_version then
    Event:create({ channel = 'syslog',
                  level = 'info',
                  msg = string.format("Middleware %s/%s has been updated to version %s",
                                     subscription.user, subscription.repo, new_version)})
    m.update(collection, subscription._id, {latest_seen_version = new_version})
  end
end

mw.check_updates = function()
  for _,subscription in ipairs(m.all(collection)) do
    mw.check_updates_for(subscrtiption)
  end
end

mw.create = function(mw_spec)
  m.create(collection, mw_spec)
end

return mw
