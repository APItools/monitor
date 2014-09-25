describe 'ServiceDemoCallsCtrl', ->
  beforeEach module('slug.controllers.services')

  [scope, ctrl] = []

  beforeEach inject ($rootScope) ->
    scope = $rootScope.$new()

  it 'assigns endpoint info', inject ($controller) ->
    $controller 'ServiceDemoCallsCtrl', $scope: scope, service: { demo: 'github' }
    expect(scope.demo).toBeDefined()

    $controller 'ServiceDemoCallsCtrl', $scope: scope, service: { demo: 'unknown' }
    expect(scope.demo).not.toBeDefined()
