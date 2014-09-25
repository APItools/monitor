describe 'TracesIndexCtrl', ->
  beforeEach module('slug.traces')

  [scope, ctrl, $httpBackend, Search, flash, Trace] = []



  beforeEach inject (_$httpBackend_, $rootScope, $controller) ->
    $httpBackend = _$httpBackend_

    Search = jasmine.createSpy('Search')
    Search.and.returnValue(Search)
    flash = {}
    scope = $rootScope.$new()
    ctrl = $controller 'TracesIndexCtrl', $scope: scope, Search: Search, flash: flash

  it 'has search', inject (Trace) ->
    expect(Search).toHaveBeenCalledWith(Trace, scope)
    expect(scope.search).toBe(Search)

  it 'queries services and filters', ->
    $httpBackend.expectGET('/api/services').respond([])
    $httpBackend.expectGET('/api/filters/traces').respond([])
    $httpBackend.flush()

    $httpBackend.verifyNoOutstandingExpectation()
    $httpBackend.verifyNoOutstandingRequest()

  it 'returns new filter', inject (TracesFilter) ->
    filter = scope.newFilter(['token'])

    expect(filter).toEqual(jasmine.any(TracesFilter))
    expect(filter.tokens).toEqual(['token'])

  it 'deletes trace', ->
    trace = jasmine.createSpyObj('Trace', ['$remove'])
    trace.$remove.and.callFake (callback) -> callback()

    scope.search = jasmine.createSpyObj('Search', ['remove'])
    scope.delete(trace)

    expect(trace.$remove).toHaveBeenCalled()
    expect(scope.search.remove).toHaveBeenCalledWith(trace)

  it 'should wipe traces when scope.wipe is called', inject (Trace) ->
    spyOn(Trace, "wipe").and.callFake (callback) -> callback()
    scope.search = jasmine.createSpyObj('Search', ['do'])

    scope.wipe()

    expect(Trace.wipe).toHaveBeenCalled()
    expect(scope.search.do).toHaveBeenCalledWith()
