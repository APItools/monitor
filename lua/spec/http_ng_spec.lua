local http_ng = require 'http_ng'
local fake_backend = require 'spec.util.fake_backend'

spy.on(fake_backend, 'send')

describe('http_ng', function()
  local http
  before_each(function()
    http = http_ng.new{backend = fake_backend}
  end)

  for _,method in ipairs{ 'get', 'head', 'options', 'delete' } do
    it('makes ' .. method .. ' call to backend', function()
      local response = http[method]('http://example.com')
      local last_request = assert(fake_backend.last_request)
      assert.spy(http.backend.send).was_called_with(last_request)
      assert.truthy(response)

      assert.equal(method:upper(), last_request.method)
      assert.equal('http://example.com', last_request.url)
    end)
  end

  for _,method in ipairs{ 'put', 'post', 'patch' } do
    it('makes ' .. method .. ' call to backend with body', function()
      local response = http[method]('http://example.com', 'body')
      local last_request = assert(fake_backend.last_request)
      assert.spy(http.backend.send).was_called_with(last_request)
      assert.truthy(response)
      assert.equal(method:upper(), last_request.method)
      assert.equal('http://example.com', last_request.url)
      assert.equal('body', last_request.body)
    end)
  end

  describe('json', function()
    it('has serializer', function()
      assert.equal(http_ng.serializers.json, http.json.serializer)
    end)

    it('doesnt have serializer', function()
      assert.falsy(http.unknown)
    end)

    it('serializes body as json', function()
      http.json.post('http://example.com', {table = 'value'})
      assert.spy(http.backend.send).was_called()
      assert.equal('{"table":"value"}', fake_backend.last_request.body)
      assert.equal(#'{"table":"value"}', fake_backend.last_request.headers['Content-Length'])
      assert.equal('application/json', fake_backend.last_request.headers['Content-Type'])
    end)

    it('accepts json as a string', function()
      http.json.post('http://example.com', '{"table" : "value"}')
      assert.spy(http.backend.send).was_called()
      assert.equal('{"table" : "value"}', fake_backend.last_request.body)
      assert.equal(#'{"table" : "value"}', fake_backend.last_request.headers['Content-Length'])
      assert.equal('application/json', fake_backend.last_request.headers['Content-Type'])
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
      assert.equal('connection refused', response.error)
    end)
  end)
end)
