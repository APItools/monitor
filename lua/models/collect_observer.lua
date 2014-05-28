local collect_observer = {}

local filter_code = function(event)
  return event.data[1].data.len > 4
end

local mail_configs = function()
  { to = 'raimonster@gmail.com' }
end

local eval_action = function(event)
  m.create("jobs:mailer", event, mail_configs())
end

collect_observer.process_event = function(event)
  if filter_code(event) then
    eval_action(event)
  end
end

return collect_observer
