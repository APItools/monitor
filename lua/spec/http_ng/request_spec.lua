local request = require 'http_ng.request'

describe('request', function()
  describe('headers', function()
    it('normalizes case', function()
      local headers = request.headers.new{ ['content-type'] = 'text/plain' }
      assert.are.same({['Content-Type'] = 'text/plain'}, headers)
    end)

    it('changes them on set', function()
      local headers = request.headers.new{}
      assert.are.same({}, headers)

      headers.host = 'example.com'
      assert.are.same({Host = 'example.com'}, headers)
      assert.equal(headers.Host, headers.host)
    end)
  end)

  it('adds User-Agent header', function()
    local req = request.new{url = 'http://example.com/path', method = 'GET' }

    assert.equal('APItools (+https://www.apitools.com)',req.headers['User-Agent'])
  end)

  it('adds Host header', function()
    local req = request.new{url = 'http://example.com/path', method = 'GET' }

    assert.equal('example.com',req.headers.Host)
  end)
end)
