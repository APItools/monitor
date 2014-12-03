file = {
  'lua/models/pipeline.lua',
  'lua/models/trace.lua',
  'lua/models/event.lua',
  'lua/http_ng.lua',
  'lua/http_ng/response.lua',
  'lua/http_ng/request.lua',
  'lua/console.lua',
  'lua/rack.lua',
  'lua/bucket.lua'
}
project = 'APItools'
title = 'APItools Middleware Documentation'
merge = true
format = 'markdown'

new_type("bucket","Bucket")
new_type("trace","Trace")
new_type("event","Event")
new_type("console","Console")
new_type("http","HTTP")
