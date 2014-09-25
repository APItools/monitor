namespace :seed do
  desc 'creates service that points to sentiment api'
  task :sentiment do
    system('curl', '-d', '{"name":"sentiment","description":"sentiment api","endpoints":[{"url":"http://api-sentiment.3scale.net","code":"sentiment"}]}', '-X', 'POST', 'http://localhost:7071/api/services/')
  end

  desc 'create stock middlewares'
  task :middlewares do
    system('curl', '-d',
           '{"version":"1", "code":"return function(req, res)\n  if res.status == 500 then\n    -- events will be shown in the notifications view\n    -- send_event gets a table with at least 3 attributes:\n    -- channel\n    -- level\n    -- msg\n  \tsend_event({channel=\"syslog\", \n        level=\"info\", \n        msg=\"path not found\"})\n  end\n  \nend", "name":"alert on 500", "description":"alerts. Drag it on pipeline to create new middleware."}',
           '-X', 'POST', 'http://localhost:7071/api/middleware_specs/')
  end

end
