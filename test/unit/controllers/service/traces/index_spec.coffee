describe 'ServiceTracesIndexCtrl', ->
  beforeEach module('slug.traces')

  [scope, ctrl, $httpBackend, Search, flash] = []

  beforeEach inject (_$httpBackend_, $rootScope, $controller) ->
    $httpBackend = _$httpBackend_

    Search = jasmine.createSpy('Seach')
    Search.and.returnValue(Search)
    flash = {}
    scope = $rootScope.$new()
    ctrl = $controller 'ServiceTracesIndexCtrl', $scope: scope, Search: Search, flash: flash

  it 'has search', inject (ServiceTrace) ->
    expect(Search).toHaveBeenCalledWith(ServiceTrace, scope)
    expect(scope.search).toBe(Search)

  it 'queries filters', ->
    $httpBackend.expectGET('/api/filters/traces').respond([])
    $httpBackend.flush()

    $httpBackend.verifyNoOutstandingExpectation()
    $httpBackend.verifyNoOutstandingRequest()

  it 'returns new filter', inject (TracesFilter) ->
    filter = scope.newFilter(['token'])

    expect(filter).toEqual(jasmine.any(TracesFilter))
    expect(filter.tokens).toEqual(['token'])

  it 'deletes trace', ->
    trace = jasmine.createSpyObj('ServiceTrace', ['$remove', '$trace'])
    trace.$trace.and.returnValue(trace)
    trace.$remove.and.callFake (callback) -> callback()

    scope.search = jasmine.createSpyObj('Search', ['remove'])
    scope.delete(trace)

    expect(trace.$remove).toHaveBeenCalled()
    expect(scope.search.remove).toHaveBeenCalledWith(trace)

  it 'should wipe service traces when scope.wipe is called', inject (ServiceTrace) ->
    spyOn(ServiceTrace, "wipe").and.callFake (callback) -> callback()
    scope.search = jasmine.createSpyObj('Search', ['do'])

    scope.wipe()

    expect(ServiceTrace.wipe).toHaveBeenCalled()
    expect(scope.search.do).toHaveBeenCalledWith()
