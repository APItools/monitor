local Model = require 'model'
local Dashboard =  Model:new()

-- Class methods

Dashboard.collection               = 'dashboards'
--Dashboard.excluded_fields_to_index = Model.build_excluded_fields('description')

return Dashboard
