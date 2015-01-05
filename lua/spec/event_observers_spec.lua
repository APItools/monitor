local Event         = require 'models.event'
local EventObserver = require 'models.event_observer'

local old_EventObserver_all     = EventObserver.all
local old_Event_get_unprocessed = Event.get_unprocessed

local function set_observers(observers)
  for i=1,#observers do
    observers[i] = EventObserver:create(observers[i])
  end
  EventObserver.all = function() return observers end
end

local function set_observer(observer)
  set_observers({observer})
end

local function set_events(events)
  Event.get_unprocessed = function()
    return events
  end
end

local function set_event(event)
  set_events({event})
end

describe('EventObserver', function()
  after_each(function()
    EventObserver.all     = old_EventObserver_all
    Event.get_unprocessed = old_Event_get_unprocessed
  end)

  it("triggers immediately", function()
    local e = {channel = 'chan', level = 'info', msg = 'lala'}
    set_event(e)
    set_observer({
      condition = "return function() return true end",
      action    = "return function(event) event.mark = true end",
      frequency = 1
    })
    EventObserver:process_events(1)
    assert.is_True(e.mark)
  end)

  it("only triggers if enough time has passed", function()
    local e = {channel = 'chan', level = 'info', msg = 'lala'}
    set_event(e)
    set_observer({
      condition = "return function() return true end",
      action    = "return function(event) event.mark = true end",
      frequency = 2
    })
    EventObserver:process_events(1)
    assert.is_Nil(e.mark)
    EventObserver:process_events(1)
    assert.is_True(e.mark)
  end)

  it("respects the condition", function()
    local event1 = {channel = 'chan', level = 'info', msg = 'lala'}
    local event2 = {channel = 'foo',  level = 'info', msg = 'lala'}
    set_events({event1, event2})
    set_observer({
      condition = "return function(event) return event.channel == 'chan' end",
      action    = "return function(event) event.mark = true end",
      frequency = 2
    })

    EventObserver:process_events(1)
    assert.is_Nil(event1.mark)
    assert.is_Nil(event2.mark)

    EventObserver:process_events(1)
    assert.is_True(event1.mark)
    assert.is_Nil(event2.mark)
  end)

  it("processes all events", function()
    local event1 = {channel = 'chan1', level = 'info', msg = 'event1'}
    local event2 = {channel = 'chan2', level = 'info', msg = 'event2'}
    set_events({event1, event2})
    set_observers({
      { condition = "return function(event) return event.channel == 'chan1' end" ,
        action    = "return function(event) event.mark = true end",
        frequency = 1
      },
      { condition = "return function(event) return event.channel == 'chan2' end" ,
        action    = "return function(event) event.mark = true end",
        frequency = 1
      }
    })
    EventObserver:process_events(1)

    assert.is_True(event1.mark)
    assert.is_True(event2.mark)
  end)

  it("respects sustained_frequency", function()
    local event = {channel = 'chan', level = 'info', msg = 'event1'}
    local observer = {
      condition = "return function(event) return event.channel == 'chan' end",
      action    = "return function(event) event.mark = true end",
      frequency = 1,
      sustained_frequency = 2
    }
    set_event(event)
    set_observer(observer)

    EventObserver:process_events(1)
    assert.is_Nil(event.mark)
    EventObserver:process_events(1)
    assert.is_True(event.mark)
  end)

  it("resets sustained_running to 0 if no event matches condition", function()
    local event = {channel = 'chan', level = 'info', msg = 'event1'}
    local observer = {
      condition = "return function(event) return event.channel == 'chan' end",
      action    = "return function(event) event.mark = true end",
      frequency = 1,
      sustained_frequency = 2
    }
    set_event(event)
    set_observer(observer)

    EventObserver:process_events(1)
    assert.is_Nil(event.mark)

    set_event()
    EventObserver:process_events(1)
    assert.is_Nil(event.mark)

    set_event(event)
    EventObserver:process_events(1)
    assert.is_Nil(event.mark)
    EventObserver:process_events(1)
    assert.is_True(event.mark)
  end)

end)
