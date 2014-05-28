local Model = require 'model'

local AutoswaggerHost = Model:new()


AutoswaggerHost.collection = 'autoswagger_hosts'
AutoswaggerHost.excluded_fields_to_index = {apis = true}


return AutoswaggerHost
