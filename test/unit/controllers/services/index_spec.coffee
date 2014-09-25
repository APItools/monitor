describe 'ServicesListCtrl', ->
  beforeEach module('slug.controllers.services')

  {scope, ctrl} = [null, null]

  beforeEach inject ($rootScope, $controller) ->
    scope = $rootScope.$new()
    ctrl = $controller 'ServicesListCtrl', $scope: scope

  it 'assigns services', ->
    expect(scope.dashboard).toBeDefined()
