local h = require 'controller_helpers'
local Brain = require 'brain'

return {
  search = function(params)
    local results = Brain.search_middleware(
        params.endpoint,
        params.query,
        params.per_page,
        params.page
    )
    h.send_json(results)
  end,

  show = function(params)
      local middleware = Brain.show_middleware(params.id)
      h.send_json(middleware)
  end
}
