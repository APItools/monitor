describe 'dashboard controller', ->
  beforeEach module('slug.dashboard')

  it 'defines a controller', inject ($controller, $rootScope) ->
    ctrl = $controller 'DashboardCtrl', $scope: $rootScope
    expect(ctrl).toBeDefined()

