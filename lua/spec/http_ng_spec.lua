local http_ng = require 'http_ng'
local fake_backend = require 'spec.util.fake_backend'


describe('http_ng', function()
  local http, backend
  before_each(function()
    backend = fake_backend.new()
    http = http_ng.new({backend = backend})
  end)

  for _,method in ipairs{ 'get', 'head', 'options', 'delete' } do
    it('makes ' .. method .. ' call to backend', function()
      local response = http[method]('http://example.com')
      local last_request = assert(backend.last_request)

      assert.truthy(response)
      assert.equal(method:upper(), last_request.method)
      assert.equal('http://example.com', last_request.url)
    end)
  end

  for _,method in ipairs{ 'put', 'post', 'patch' } do
    it('makes ' .. method .. ' call to backend with body', function()
      local response = http[method]('http://example.com', 'body')
      local last_request = assert(backend.last_request)

      assert.truthy(response)
      assert.equal(method:upper(), last_request.method)
      assert.equal('http://example.com', last_request.url)
      assert.equal('body', last_request.body)
    end)
  end

  describe('x-www-form-urlencoded', function()
    local body = { value = 'some' }

    it('serializes table as form-urlencoded', function()
      local response = http.post('http://example.com', body)
      local last_request = assert(backend.last_request)
      assert.equal('application/x-www-form-urlencoded', last_request.headers.content_type)
      assert.equal('value=some', last_request.body)
    end)
  end)

  describe('array syntax', function()
    it('works for get', function()
      local response = http.get{'http://example.com', headers = { custom = 'value'} }
      local last_request = assert(backend.last_request)
      assert.equal('value', last_request.headers.custom)
    end)

    it('works for post', function()
      local response = http.post{'http://example.com', 'body', headers = { custom = 'value'} }
      local last_request = assert(backend.last_request)
      assert.equal('value', last_request.headers.Custom)
      assert.equal('body', last_request.body)
    end)
  end)

  describe('headers', function()
    local headers = { custom_header = 'value' }

    it('can override Host header', function()
      local response = http.get('http://example.com', { headers = { host = 'overriden' }})
      local last_request = assert(backend.last_request)
      assert.equal('overriden', last_request.headers.host)
    end)

    it('passed headers for requests with body', function()
      local response = http.post('http://example.com', '', { headers = headers })
      local last_request = assert(backend.last_request)
      assert.equal('value', last_request.headers['Custom-Header'])
    end)

    it('passed headers for requests without body', function()
      local response = http.get('http://example.com', { headers = headers })
      local last_request = assert(backend.last_request)
      assert.equal('value', last_request.headers['Custom-Header'])
    end)
  end)

  describe('json', function()
    it('has serializer', function()
      assert.equal(http_ng.serializers.json, http.json.serializer)
    end)

    it('doesnt have serializer', function()
      assert.falsy(http.unknown)
    end)

    it('serializes body as json', function()
      http.json.post('http://example.com', {table = 'value'})

      assert.equal('{"table":"value"}', backend.last_request.body)
      assert.equal(#'{"table":"value"}', backend.last_request.headers['Content-Length'])
      assert.equal('application/json', backend.last_request.headers['Content-Type'])
    end)

    it('accepts json as a string', function()
      http.json.post('http://example.com', '{"table" : "value"}')
      assert.equal('{"table" : "value"}', backend.last_request.body)
      assert.equal(#'{"table" : "value"}', backend.last_request.headers['Content-Length'])
      assert.equal('application/json', backend.last_request.headers['Content-Type'])
    end)

    it('does not override passed headers', function()
      http.json.post('http://example.com', '{}', { headers = { content_type = 'custom/format' }})
      assert.equal('custom/format', backend.last_request.headers['Content-Type'])
    end)
  end)

  describe('when there is no error', function()
    local response
    before_each(function()
      http = http_ng.new{}
      response = http.get('http://127.0.0.1:8081')
    end)

    it('is ok', function()
      assert.equal(true, response.ok)
    end)

    it('has no error', function()
      assert.equal(nil, response.error)
    end)
  end)

  describe('when there is error', function()
    local response
    before_each(function()
      http = http_ng.new{}
      response = http.get('http://127.0.0.1:1000')
    end)

    it('is not ok', function()
      assert.equal(false, response.ok)
    end)

    it('has error', function()
      assert.equal('string', type(response.error)) -- depending on the openresty version it can be "timeout" or "connection refused"
    end)
  end)

  describe('works with api.twitter.com', function()

    it('connects #twitter', function()
      local http = http_ng.new{}
      local response = http.get('http://api.twitter.com/')
      assert(response.ok, 'response is not ok')
    end)
  end)
end)
