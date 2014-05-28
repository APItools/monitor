local h = require 'controller_helpers'
local m = require 'model_helpers'
local mw_s = require 'models.mw_subscriptions'

local function create_middleware_spec(params)
  local mw_specs = require 'controllers.middleware_specs_controller'
  mw_specs.create(params)
end


local collection = 'mw_subscriptions'
local mw_subscriptions = {
  show = function(params)
    local service = m.find_or_error(collection, params.id)
    h.send_json(service)
  end,

  index = function(params)
    h.send_json(m.all(collection))
  end,

  get_spec = function(params)
    local user = params.user
    local repo = params.repo
    local spec = mw_s.get_updates(user, repo)
    h.send_json(spec)
  end,

  create_from_spec = function(params)
    local spec = m.find_or_error(params.id)
    m.create(collection, {})
  end,

  -- you can create a subscription from 2 places
  -- when downloading a mw from gh.
  -- when you just created the plugin and push
  create = function(params)
    local user = params.user
    local repo = params.repo
    if m.exist(collection, {user = user, repo = repo}) then
      h.send_json({error = "already subscribed to middleware" .. user .. "/" .. repo }
                  , 403)
    end

    local spec = create_middleware_spec(params) -- should create the spec and return the spec
    if not spec.id then
      error("spec could not be created")
    end

    m.create(collection,
             {author = params.author,
              user = params.user,
              repo = params.repo,
              current_version = params.current_version,
              last_seen_version = params.current_version,
              description = params.description,
              spec_id = spec._id
             })

  end,
}


return mw_subscriptions
