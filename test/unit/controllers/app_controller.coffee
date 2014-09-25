describe 'AppController', ->
  beforeEach module('slug.controllers')

  {scope, ctrl} = [null, null]

  beforeEach inject ($rootScope, $controller) ->
    scope = $rootScope.$new()
    ctrl = $controller 'AppController', $scope: scope

  xit 'assigns services', ->
    expect(scope.services).toBeDefined()