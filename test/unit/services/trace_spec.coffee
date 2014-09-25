describe "Trace Service", ->

  [Trace, $httpBackend] = []

  beforeEach module('slug.traces')
  beforeEach inject (_Trace_, _$httpBackend_) ->
    $httpBackend = _$httpBackend_
    Trace = _Trace_

  afterEach ->
    $httpBackend.verifyNoOutstandingExpectation()
    $httpBackend.verifyNoOutstandingRequest()

  it 'does', ->
    Trace.wipe()
    $httpBackend.expectDELETE('/api/traces/all').respond()
    $httpBackend.flush()
