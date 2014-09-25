describe 'ServiceDestroyCtrl', ->
  beforeEach module('slug.controllers.services')

  [scope, ctrl, $httpBackend, stateParams] = []

  beforeEach inject (_$httpBackend_, $rootScope, $controller) ->
    stateParams = {}

    $httpBackend = _$httpBackend_

    scope = $rootScope.$new()

    ctrl = -> $controller 'ServiceDestroyCtrl', $scope: scope, $stateParams: stateParams

  afterEach ->
    $httpBackend.verifyNoOutstandingExpectation()
    $httpBackend.verifyNoOutstandingRequest()

  it 'destroys the service', ->
    scope.service = jasmine.createSpyObj('Service', ['$remove'])
    ctrl()
    scope.destroy()
    expect(scope.service.$remove).toHaveBeenCalled()

  it 'removes the service from the scope.services', ->
    service = scope.service = { _id: 3, $remove: (callback) -> callback(service) }
    scope.services = [service]

    ctrl()
    scope.destroy()

    expect(scope.services.length).toBe(0)

  it 'loads service when there is none from previous scope', ->
    stateParams.serviceId = 37
    ctrl()
    $httpBackend.expect('GET', '/api/services/37').respond({_id: 37})
    $httpBackend.flush()

  it 'does not load service when there is one', ->
    scope.service = 'existing'
    ctrl()
    $httpBackend.verifyNoOutstandingRequest()
