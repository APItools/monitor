describe 'TraceShowCtrl', ->
  beforeEach module('slug.traces')

  [scope, ctrl, $httpBackend, stateParams] = []

  beforeEach inject (_$httpBackend_, $rootScope, $controller) ->
    $httpBackend = _$httpBackend_

    stateParams = traceId: 42

    scope = $rootScope.$new()
    ctrl = $controller 'TraceShowCtrl', $scope: scope, $stateParams: stateParams

  it 'loads the trace', ->
    expect(scope.trace).toBeDefined()

    $httpBackend.expectGET('/api/traces/42').respond(service_id: 1)
    $httpBackend.expectGET('/api/services/1').respond()

    $httpBackend.flush()
