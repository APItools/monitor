local backend = require 'http_ng.backend.resty'

describe('resty backend', function()

  describe('GET method', function()
    local method = 'GET'

    it('accesses the url', function()
      local response, err = backend.send{method = method, url = 'http://example.com/'}
      assert.falsy(err)
      assert.truthy(response)
    end)

    it('works with ssl', function()
      local response, err = backend.send{method = method, url = 'https://google.com/' }
      assert.falsy(err)
      assert.truthy(response)
      assert(response.headers.location:match('^https://'))
    end)
  end)
end)
