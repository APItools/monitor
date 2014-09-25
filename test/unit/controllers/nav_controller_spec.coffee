describe 'NavController', ->
  beforeEach module('slug')
  beforeEach module('slug.controllers')

  {scope, ctrl} = [null, null]

  beforeEach inject ($rootScope, $controller) ->
    scope = $rootScope.$new()
    scope.navigation = {}
    ctrl = $controller 'NavController', $scope: scope

  xit 'assigns template', ->
    expect(scope.template).toBe('/navigation.html')

  xit 'assigns controller to navigation', ->
    expect(scope.navigation.controller).toBe(ctrl)