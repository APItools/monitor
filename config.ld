file = {
  'lua/models/pipeline.lua',
  'lua/models/trace.lua',
  'lua/models/event.lua',
  'lua/console.lua',
  'lua/bucket.lua'
}
project = 'APItools'
title = 'APItools Middleware Documentation'
merge = true

new_type("bucket","Bucket")
new_type("trace","Trace")
new_type("event","Event")
new_type("console","Console")
