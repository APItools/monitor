describe "Notifications Service", ->

  [Event, $httpBackend] = []

  beforeEach module('slug.notifications')
  beforeEach inject (_Event_, _$httpBackend_) ->
    $httpBackend = _$httpBackend_
    Event = _Event_

  afterEach ->
    $httpBackend.verifyNoOutstandingExpectation()
    $httpBackend.verifyNoOutstandingRequest()

  it 'does', ->
    Event.wipe()
    $httpBackend.expectDELETE('/api/events/all').respond()
    $httpBackend.flush()
