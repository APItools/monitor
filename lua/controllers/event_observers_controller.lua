local h             = require 'controller_helpers'
local EventObserver = require 'models.event_observer'


local event_observers = {
  index = function(params)
    h.send_json(EventObserver:all())
  end,

  show = function(params)
    h.send_json(EventObserver:find_or_error(params.id, 'event_observer not found'))
  end,

  -- creation of an event_observer with a given unique name. if
  -- there's no 'name' param, a timestamp will be used
  create = function(params)
    local obj = h.request_json()
    if not obj.name then
      obj.name = tostring(ngx.now())
    else

      if EventObserver:find({ name = obj.name }) then
        local json = {
          status = 'error',
          msg    = 'an event with this name already exists. Try a different one'
        }
        return h.send_json(json, ngx.HTTP_FORBIDDEN)
      end
    end

    local observer = EventObserver:create(obj)
    h.send_json(observer, ngx.HTTP_CREATED)
  end,

  update = function(params)
    local observer = EventObserver:update({_id = tonumber(params.id)}, h.request_json())
    h.send_json(observer)
  end,

  delete = function(params)
    EventObserver:delete_or_error({_id = tonumber(params.id)}, 'event_observer not found')
  end
}

return event_observers
