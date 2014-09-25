describe "BrainMiddlewareSpec Service", ->

  [BrainMiddlewareSpec, $httpBackend] = []

  beforeEach module('slug.brain_middleware_specs')
  beforeEach inject (_BrainMiddlewareSpec_, _$httpBackend_) ->
    $httpBackend = _$httpBackend_
    BrainMiddlewareSpec = _BrainMiddlewareSpec_

  afterEach ->
    $httpBackend.verifyNoOutstandingExpectation()
    $httpBackend.verifyNoOutstandingRequest()


  it 'does middleware spec search from brain', ->
    BrainMiddlewareSpec.search endpoint: "*"
    $httpBackend.expectGET('/api/brain/middleware_specs/search?endpoint=*').respond()
    $httpBackend.flush()
