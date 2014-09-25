describe "ServiceTrace Service", ->

  [ServiceTrace, $httpBackend] = []

  beforeEach module('slug.traces')
  beforeEach inject (_ServiceTrace_, _$httpBackend_) ->
    $httpBackend = _$httpBackend_
    ServiceTrace = _ServiceTrace_

  afterEach ->
    $httpBackend.verifyNoOutstandingExpectation()
    $httpBackend.verifyNoOutstandingRequest()

  it 'does', ->
    ServiceTrace.wipe()
    $httpBackend.expectDELETE('/api/services/traces/all').respond()
    $httpBackend.flush()
