local backend = require 'http_ng.backend.ngx'

describe('ngx backend',function()
  describe('GET method', function()
    local method = 'GET'

    it('accesses the url', function()
      backend.capture = function(location, options)
        assert.equal('/___http_call', location)
        assert.equal(ngx.HTTP_GET, options.method)
        assert.are.same({_url = 'http://localhost:8081'}, options.vars)
        return { status = 200, body = '' }
      end
      local response = backend.send{method = method, url = 'http://localhost:8081' }
      assert.truthy(response)
    end)

    it('sends headers', function()
      backend.capture = function(location, options)
        assert.equal('/___http_call', location)
        assert.equal(ngx.HTTP_GET, options.method)
        assert.are.same({Host = 'fake.example.com'}, options.ctx.headers)
        return { status = 200, body = '' }
      end
      local response = backend.send{method = method, url = 'http://localhost:8081/path', headers = {Host = 'fake.example.com'} }
      assert.truthy(response)
    end)
  end)


end)
